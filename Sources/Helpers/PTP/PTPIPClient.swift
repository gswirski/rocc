//
//  PTPIPClient.swift
//  CCKit
//
//  Created by Simon Mitchell on 29/01/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

typealias CommandRequestPacketResponse = (_ packet: CommandResponsePacket) -> Void

extension Packetable {
    
    var debugDescription: String {
        return description
    }
    
    var description: String {
        return """
        {
            length: \(length)
            code: \(name)
            data: \(data.toHex)
        }
        """
    }
}

/// A client for transferring images using the PTP IP protocol
final class PTPIPClient {
    
    private static var mutex = NSObject()

    //MARK: - Initialisation -
    
    internal let ptpClientLog = OSLog(subsystem: "com.yellow-brick-bear.rocc", category: "PTPIPClient")
    
    private var packetStream: PTPPacketStream
    
    private var currentTransactionId: DWord = 0
    
    private var guid: String
    
    init(camera: Camera, packetStream: PTPPacketStream) {
        self.packetStream = packetStream
        // Remove any unwanted components from camera's identifier
        guid = camera.identifier.replacingOccurrences(of: "uuid", with: "").components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        // Trim GUID to 16 characters
        guid = String(guid.suffix(16))
        self.packetStream.delegate = self
    }
    
    func resetTransactionId(to: DWord) {
        currentTransactionId = to
    }
    
    func getNextTransactionId() -> DWord {
        objc_sync_enter(PTPIPClient.mutex)

        defer {
            if currentTransactionId == DWord.max {
                currentTransactionId = 0
            } else {
                currentTransactionId += 1
            }
            
            objc_sync_exit(PTPIPClient.mutex)
        }
        
        return currentTransactionId
    }
    
    var onEvent: ((_ event: EventPacket) -> Void)?
    
    var onDisconnect: (() -> Void)?
    
    #if canImport(UIKit)
    var deviceName: String = UIDevice.current.name
    #elseif canImport(AppKit)
    var deviceName: String = Host.current().name ?? UUID().uuidString
    #else
    var deviceName: String = UUID().uuidString
    #endif
    
    //MARK: - Connection -
    
    var connectCallback: ((_ error: Error?) -> Void)?
    
    func connect(callback: @escaping (_ error: Error?) -> Void) {
        connectCallback = callback
        packetStream.connect(callback: callback)
    }
    
    func disconnect() {
        packetStream.disconnect()
        commandRequestCallbacks = [:]
        dataContainers = [:]
    }
    
    private func sendInitCommandRequest() {
        
        let guidData = "8810B99668841894".data(using: .utf8)
        let guidBytes = ByteBuffer(hexString: "41 86 d4 f7 1f 9b 42 86  88 4d fb c1 1e e8 8b d9").bytes.compactMap { $0 }
        let connectPacket = Packet.initCommandPacket(guid: guidBytes, name: deviceName)
        sendControlPacket(connectPacket)
        
        Logger.log(message: "Sending InitCommandPacket to PTP IP Device", category: "PTPIPClient", level: .debug)
        os_log("Sending InitCommandPacket to PTP IP Device", log: ptpClientLog, type: .debug)
    }
        
    //MARK: - Sending Packets -
    
    fileprivate var pendingEventPackets: [Packetable] = []
    
    fileprivate var pendingControlPackets: [Packetable] = []
    
    var onEventStreamsOpened: (() -> Void)?
    
    /// Sends a packet to the event loop of the PTP IP connection
    /// - Parameter packet: The packet to send
    fileprivate func sendEventPacket(_ packet: Packetable) {
        packetStream.sendEventPacket(packet)
    }
    
    /// Sends a packet to the control loop of the PTP IP connection
    /// - Parameter packet: The packet to send
    func sendControlPacket(_ packet: Packetable) {
        packetStream.sendControlPacket(packet)
    }
    
    //MARK: Command Requests
    
    private var commandRequestCallbacks: [DWord : (callback: CommandRequestPacketResponse, callForAnyResponse: Bool)] = [:]
    
    /// Sends a command request packet to the control loop of the PTP IP connection with optional callback
    /// - Important: If you are making a call that you do not expect to receive a CommandResponse in response to
    /// then `callback` may never be called.
    ///
    /// - Parameter packet: The packet to send
    /// - Parameter callback: An optional callback which will be called with the received CommandResponse packet
    /// - Parameter callCallbackForAnyResponse: Whether the callback should be called for any response received regardless of whether it contains a transaction ID or what it's transaction ID is. This fixes issues with the OpenSession command response Sony sends which doesn't contain a transaction ID.
    func sendCommandRequestPacket(_ packet: CommandRequestPacket, callback: CommandRequestPacketResponse?, callCallbackForAnyResponse: Bool = false) {
        if let _callback = callback {
            commandRequestCallbacks[packet.transactionId] = (_callback, callCallbackForAnyResponse)
        }
        sendControlPacket(packet)
    }
    
    func setDevicePropValueEx(_ value: PTP.DeviceProperty.Value, _ code: UInt32, callback: CommandRequestPacketResponse? = nil) {
        let transactionID = getNextTransactionId()
        let opRequestPacket = Packet.commandRequestPacket(code: .canonSetDevicePropValueEx, arguments: [], transactionId: transactionID, dataPhaseInfo: 2)
        var data = ByteBuffer()
        data.appendValue(UInt32(12), ofType: .uint32)
        data.appendValue(code, ofType: .uint32) // aperture
        data.appendValue(value.value, ofType: .uint32)
        
        let dataPackets = Packet.dataSendPackets(data: data, transactionId: transactionID)
        
        sendCommandRequestPacket(opRequestPacket, callback: callback)
        dataPackets.forEach { (dataPacket) in
            sendControlPacket(dataPacket)
        }
    }
    
    func getViewFinderData(callback: @escaping DataResponse) {
        let transactionID = getNextTransactionId()
        let opRequestPacket = Packet.commandRequestPacket(code: .canonGetViewFinderData, arguments: [0x00200000, 0x00000001, 0x00000000], transactionId: transactionID, dataPhaseInfo: 1)
        
        print("Canon Live View sending")
        sendCommandRequestPacket(opRequestPacket, callback: { (response) in
            print("Canon Live View response A")
        })
        awaitDataFor(transactionId: transactionID, callback: callback)
    }
    
    func sendSetControlDeviceAValue(_ value: PTP.DeviceProperty.Value, callback: CommandRequestPacketResponse? = nil) {
        
        let transactionID = getNextTransactionId()
        let opRequestPacket = Packet.commandRequestPacket(code: .setControlDeviceA, arguments: [DWord(value.code.rawValue)], transactionId: transactionID, dataPhaseInfo: 2)
        var data = ByteBuffer()
        data.appendValue(value.value, ofType: value.type)
        let dataPackets = Packet.dataSendPackets(data: data, transactionId: transactionID)
        
        sendCommandRequestPacket(opRequestPacket, callback: callback)
        dataPackets.forEach { (dataPacket) in
            sendControlPacket(dataPacket)
        }
    }
    
    func sendSetControlDeviceBValue(_ value: PTP.DeviceProperty.Value, callback: CommandRequestPacketResponse? = nil) {
        
        let transactionID = getNextTransactionId()
        let opRequestPacket = Packet.commandRequestPacket(code: .setControlDeviceB, arguments: [DWord(value.code.rawValue)], transactionId: transactionID, dataPhaseInfo: 2)
        var data = ByteBuffer()
        data.appendValue(value.value, ofType: value.type)
        let dataPackets = Packet.dataSendPackets(data: data, transactionId: transactionID)
        
        sendCommandRequestPacket(opRequestPacket, callback: callback, callCallbackForAnyResponse: true)
        dataPackets.forEach { (dataPacket) in
            sendControlPacket(dataPacket)
        }
    }
    
    var onPong: (() -> Void)?
    
    func ping(callback: @escaping (Error?) -> Void) {
        
        sendEventPacket(Packet.pongPacket())
        onPong = { [weak self] in
            callback(nil)
            self?.onPong = nil
        }
    }
    
    //MARK: - Handling Responses -
    
    fileprivate func handle(packet: Packetable) {
        
        if packet as? CommandResponsePacket == nil || !(packet as! CommandResponsePacket).awaitingFurtherData {
            Logger.log(message: "Received packet from device: \(packet.debugDescription)", category: "PTPIPClient", level: .debug)
            os_log("Received packet from device: %@", log: ptpClientLog, type: .debug, "\(packet.debugDescription)")
        }
        
        switch packet {
        case let initCommandAckPacket as InitCommandAckPacket:
            
            onEventStreamsOpened = { [weak self] in
                let initEventPacket = Packet.initEventPacket(sessionId: initCommandAckPacket.sessionId)
                self?.sendEventPacket(initEventPacket)
            }
            
            packetStream.setupEventLoop()
        case let commandResponsePacket as CommandResponsePacket:
            handleCommandResponsePacket(commandResponsePacket)
        case let dataStartPacket as StartDataPacket:
            handleStartDataPacket(dataStartPacket)
        case let dataPacket as DataPacket:
            handleDataPacket(dataPacket)
        case let endDataPacket as EndDataPacket:
            handleEndDataPacket(endDataPacket)
        case let eventPacket as EventPacket:
            print("Calling onEvent")
            onEvent?(eventPacket)            
        default:
            switch packet.name {
            case .initEventAck:
                // We're done with setting up sockets here, any further handshake should be done by the caller of `connect`
                connectCallback?(nil)
                connectCallback = nil
            case .ping:
                // Perform a pong!
                let pongPacket = Packet.pongPacket()
                sendEventPacket(pongPacket)
            case .pong:
                onPong?()
            default:
                break
            }
            break
        }
    }
    
    fileprivate func handle(packets: [Packetable]) {
        packets.forEach { (packet) in
            handle(packet: packet)
        }
    }
    
    //MARK: Commands
        
    fileprivate func handleCommandResponsePacket(_ packet: CommandResponsePacket) {
        
        print("handleCommandResponsePacket A")

        
        // Need to catch this, as sometimes cameras send invalid command responses, but sometimes they just
        // come through in multiple bundles, so we wait and augment them with further data
        guard !packet.awaitingFurtherData else {
            return
        }
        
        print("handleCommandResponsePacket B")
        
        guard let transactionId = packet.transactionId else {
            commandRequestCallbacks = commandRequestCallbacks.filter { (_, value) -> Bool in
                // If not called for any response, then leave it in the callbacks dictionary
                guard value.callForAnyResponse else { return true }
                value.callback(packet)
                return false
            }
            return
        }
        
        // Nil callback out before calling it to avoid race-conditions (especially important in tests)
        let callback = commandRequestCallbacks[transactionId]
        commandRequestCallbacks[transactionId] = nil
        callback?.callback(packet)
        
        if !packet.code.isError, let containerForData = dataContainers[transactionId] {
            // Nil callback out before calling it to avoid race-conditions (especially important in tests)
            let dataCallback = dataCallbacks[transactionId]
            dataCallbacks[transactionId] = nil
            dataCallback?(Result.success(containerForData))
        }
        
        guard packet.code.isError else { return }
        
        let dataCallback = dataCallbacks[transactionId]
        dataCallbacks[transactionId] = nil
        dataCallback?(Result.failure(packet.code))
    }
    
    //MARK: Data
    
    internal var dataCallbacks: [DWord : DataResponse] = [:]
    
    internal var dataContainers: [DWord : DataContainer] = [:]
        
}



//MARK: - StreamDelegate implementation

extension PTPIPClient: PTPPacketStreamDelegate {
    
    func packetStream(_ stream: PTPPacketStream, didReceive packets: [Packetable]) {
        handle(packets: packets)
    }
    
    func packetStreamDidDisconnect(_ stream: PTPPacketStream) {
        onDisconnect?()
    }
    
    func packetStreamDidOpenControlStream(_ stream: PTPPacketStream) {
        self.sendInitCommandRequest()
    }
    
    func packetStreamDidOpenEventStream(_ stream: PTPPacketStream) {
        self.onEventStreamsOpened?()
    }
}

enum PTPIPClientError: Error {
    case invalidResponse
    case failedToCreateStreamsToHost
    case socketClosed
}
