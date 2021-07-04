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

struct CommandRequestPacketArguments {
    let commandCode: PTP.CommandCode
    let arguments: [DWord]?
    let data: ByteBuffer?
    let phaseInfo: Int?
    
    init(commandCode: PTP.CommandCode, arguments: [DWord]? = nil, data: ByteBuffer? = nil, phaseInfo: Int? = nil){
        self.commandCode = commandCode
        self.arguments = arguments
        self.data = data
        self.phaseInfo = phaseInfo
    }
}

/// A client for transferring images using the PTP IP protocol
final class PTPIPClientNext {

    let ptpQueue = DispatchQueue(label: "PTPIPDispatchQueue", qos: .userInteractive, attributes: DispatchQueue.Attributes(), autoreleaseFrequency: .inherit, target: nil)

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
        defer {
            if currentTransactionId == DWord.max {
                currentTransactionId = 0
            } else {
                currentTransactionId += 1
            }
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
        print("PTP/IP Connection connect in PTP client next")
        connectCallback = callback
        packetStream.connect(callback: callback)
    }
    
    func disconnect() {
        packetStream.disconnect()
        commandRequestCallbacks = [:]
        dataContainers = [:]
    }
    
    private func sendInitCommandRequest() {
        let guidBytes = ByteBuffer(hexString: "41 86 d4 f7 1f 9b 42 86  88 4d fb c1 1e e8 8b d9").bytes.compactMap { $0 }
        let connectPacket = Packet.initCommandPacket(guid: guidBytes, name: "Shutter")
        sendControlPacket(connectPacket)
        
        Logger.log(message: "Sending InitCommandPacket to PTP IP Device", category: "PTPIPClient", level: .debug)
        os_log("Sending InitCommandPacket to PTP IP Device", log: ptpClientLog, type: .debug)
    }
        
    //MARK: - Sending Packets -
    
    fileprivate var pendingEventPackets: [Packetable] = []
    
    fileprivate var pendingControlPackets: [Packetable] = []
    
    var onEventStreamsOpened: (() -> Void)?
    
    
    struct PendingCommandRequest {
        let packet: CommandRequestPacketArguments
        let responseHandler: CommandRequestPacketResponse?
        let dataHandler: DataResponse?
    }
    
    enum PendingCommandPriority: Int, CaseIterable {
        case high
        case normal
        case low
    }

    fileprivate var pendingCommandPackets: [PendingCommandPriority: [PendingCommandRequest]] = [
        .high: [],
        .normal: [],
        .low: []
    ]
    fileprivate var isExecutingCommandPacket: Bool = false
    
    /// Sends a packet to the event loop of the PTP IP connection
    /// - Parameter packet: The packet to send
    fileprivate func sendEventPacket(_ packet: Packetable) {
        packetStream.sendEventPacket(packet)
    }
    
    /// Sends a packet to the control loop of the PTP IP connection
    /// - Parameter packet: The packet to send
    private func sendControlPacket(_ packet: Packetable) {
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
    private func sendCommandRequestPacket(_ packet: CommandRequestPacket, callback: CommandRequestPacketResponse?, callCallbackForAnyResponse: Bool = false) {
        if let _callback = callback {
            commandRequestCallbacks[packet.transactionId] = (_callback, callCallbackForAnyResponse)
        }
        sendControlPacket(packet)
    }
    
    func processNextPendingCommandPacket() {
        ptpQueue.async {
            //print("PTPQueue - start isExecutingAlready: \(self.isExecutingCommandPacket) \(self.debugPendingCommandQueue())")
            guard !self.isExecutingCommandPacket else { return }
            guard self.hasPendingCommands() else { return }

            let pending = self.removeFirstPendingCommand()
            //print("PTPQueue - executing \(pending)")
            
            self.isExecutingCommandPacket = true
            
            var awaitingResponse = true
            var awaitingData = (pending.dataHandler != nil)
            
            let checkConditionsAndProceed = { [weak self] () in
                guard let self = self else { return }
                
                //print("PTPQueue - awaiting \(awaitingResponse) \(awaitingData)")
                guard !awaitingResponse && !awaitingData else { return }

                self.isExecutingCommandPacket = false
                self.processNextPendingCommandPacket()
            }
            
            let transactionId = self.getNextTransactionId()
            let phaseInfo = pending.packet.phaseInfo.map { DWord($0) } ?? 1
            let packet = Packet.commandRequestPacket(code: pending.packet.commandCode, arguments: pending.packet.arguments, transactionId: transactionId, dataPhaseInfo: phaseInfo)
            
            //print("PTPQueue - setting transaction id: \(packet.transactionId), awaiting respo \(awaitingResponse) awaitingData \(awaitingData) -> \(pending.packet.commandCode)")
            
            self.sendCommandRequestPacket(packet, callback: { (response) in
                //print("PTPQueue - received response \(response)")
                if let responseHandler = pending.responseHandler {
                    DispatchQueue.global(qos: .userInteractive).async {
                        responseHandler(response)
                    }
                }
                awaitingResponse = false
                if let dataHandler = pending.dataHandler, response.code != .okay, awaitingData {
                    // TODO: this might be required for Sony?
                    /*DispatchQueue.global(qos: .userInteractive).async {
                        dataHandler(Result.failure(response.code))
                    }*/
                    //awaitingData = false
                }
                checkConditionsAndProceed()
            }, callCallbackForAnyResponse: false)
            
            if let data = pending.packet.data {
                let dataPackets = Packet.dataSendPackets(data: data, transactionId: transactionId)
                dataPackets.forEach { (dataPacket) in
                    self.sendControlPacket(dataPacket)
                }
            }

            
            if let dataHandler = pending.dataHandler {
                self.awaitDataFor(transactionId: packet.transactionId) { (response) in
                    let length = response.map { (data) in
                        return data.data.length
                    }
                    //print("PTPQueue - received data for transaction \(packet.transactionId), length: \(length)")
                    DispatchQueue.global(qos: .userInteractive).async {
                        dataHandler(response)
                    }
                    awaitingData = false
                    checkConditionsAndProceed()
                }
            }
        }
    }

    func sendCommandRequestPacketRestrictedToInitialization(_ packet: CommandRequestPacket, callback: CommandRequestPacketResponse?, callCallbackForAnyResponse: Bool = false) {
        sendCommandRequestPacket(packet, callback: callback, callCallbackForAnyResponse: callCallbackForAnyResponse)
    }
    
    func sendCommandRequestPacket(_ packet: CommandRequestPacketArguments, priority: PendingCommandPriority, responseCallback: CommandRequestPacketResponse?, dataCallback: DataResponse?) {
        ptpQueue.async {
            if packet.commandCode == .canonGetViewFinderData && self.pendingCommandPackets[.low]!.contains(where: { pendingCommand in
                return pendingCommand.packet.commandCode == .canonGetViewFinderData
            }) {
                // TODO: not ideal, but meh...
                //fatalError("requesting a frame before the previous one finished processing")
            }
            self.pendingCommandPackets[priority]!.append(PendingCommandRequest(packet: packet, responseHandler: responseCallback, dataHandler: dataCallback))
            self.processNextPendingCommandPacket()
        }
    }

    func setDevicePropValueEx(_ value: PTP.DeviceProperty.Value, _ code: PTPDevicePropertyDataType, callback: CommandRequestPacketResponse? = nil) {
        var data = ByteBuffer()
        data.appendValue(UInt32(12), ofType: .uint32)
        data.appendValue(code, ofType: .uint32) // aperture
        data.appendValue(value.value, ofType: .uint32)

        let packet = CommandRequestPacketArguments(commandCode: .canonSetDevicePropValueEx, arguments: [], data: data, phaseInfo: 2)
        
        sendCommandRequestPacket(packet, priority: .normal, responseCallback: callback, dataCallback: nil)
        
    }
    
    func sendCanonPing(callback: CommandRequestPacketResponse? = nil) {
        print("SENDING PING!!")
        let packet = CommandRequestPacketArguments(commandCode: .canonPing, arguments: nil)
        sendCommandRequestPacket(packet, priority: .low, responseCallback: callback, dataCallback: nil)
    }
    
    func canonSetAFPoint(_ point: CGPoint, callback: CommandRequestPacketResponse? = nil) {
        let packet = CommandRequestPacketArguments(commandCode: .canonTouchAfPosition, arguments: [0x03, UInt32(point.x), UInt32(point.y), 0x00])
        sendCommandRequestPacket(packet, priority: .normal, responseCallback: callback, dataCallback: nil)
    }
    
    func getViewFinderData(callback: @escaping DataResponse) {
        let opRequestPacket = CommandRequestPacketArguments(commandCode: .canonGetViewFinderData, arguments: [0x00200000, 0x00000001, 0x00000000])
        
        //print("Canon Live View sending")
        
        
        sendCommandRequestPacket(opRequestPacket, priority: .low, responseCallback: { (response) in
            //print("Canon Live View response A")
        }, dataCallback: callback)
    }
    
    func sendRemoteReleaseOn(callback: CommandRequestPacketResponse? = nil) {
        let opRequestPacket = CommandRequestPacketArguments(commandCode: .canonRemoteReleaseOn, arguments: [0x03, 0x00])
        
        sendCommandRequestPacket(opRequestPacket, priority: .normal, responseCallback: callback, dataCallback: nil)
    }
    
    func sendRemoteReleaseOff(callback: CommandRequestPacketResponse? = nil) {
        let opRequestPacket = CommandRequestPacketArguments(commandCode: .canonRemoteReleaseOff, arguments: [0x03])
        
        sendCommandRequestPacket(opRequestPacket, priority: .normal, responseCallback: callback, dataCallback: nil)
    }
    
    func getReducedObject(objectId: DWord, callback: @escaping DataResponse) {
        let opRequestPacket = CommandRequestPacketArguments(commandCode: .canonGetReducedObject, arguments: [objectId, 0x00200000, 0x00000000])
        print("Canon getThumbEx")
        sendCommandRequestPacket(opRequestPacket, priority: .normal, responseCallback: { (response) in
            print("Canon getThumbEx response A")
        }, dataCallback: callback)
    }

    func requestInnerDevelopStart(objectId: DWord, callback: CommandRequestPacketResponse? = nil) {
        let opRequestPacket = CommandRequestPacketArguments(
            commandCode: .canonRequestInnerDevelopStart, arguments: [objectId, 0x04],
            data: ByteBuffer(hexString: "0f 00 00 00 02 00 00 00"),
            phaseInfo: 2
        )
        sendCommandRequestPacket(opRequestPacket, priority: .normal, responseCallback: callback, dataCallback: nil)
    }
    
    func requestInnerDevelopEnd(callback: CommandRequestPacketResponse? = nil) {
        let opRequestPacket = CommandRequestPacketArguments(
            commandCode: .canonRequestInnerDevelopEnd, arguments: [0x0],
            data: ByteBuffer(hexString: "00 00 00 00"),
            phaseInfo: 2
        )
        sendCommandRequestPacket(opRequestPacket, priority: .normal, responseCallback: callback, dataCallback: nil)

    }
    
    func transferComplete(objectId: DWord, callback: CommandRequestPacketResponse? = nil) {
        let opRequestPacket = CommandRequestPacketArguments(
            commandCode: .canonTransferComplete, arguments: [objectId]
        )
        sendCommandRequestPacket(opRequestPacket, priority: .normal, responseCallback: callback, dataCallback: nil)

    }
    
    func getPartialObject(objectId: DWord, offset: DWord, maxbyte: DWord, callback: @escaping DataResponse) {
        let opRequestPacket = CommandRequestPacketArguments(
            commandCode: .canonGetPartialObject64, arguments: [objectId, offset, maxbyte, 0x0]
        )
        sendCommandRequestPacket(opRequestPacket, priority: .normal, responseCallback: { (response) in
            print("Canon getThumbEx getPartialObject response A \(response.transactionId)")
        }, dataCallback: { (response) in
            print("Canon getThumbEx getPartialObject response B")
            callback(response)
        })

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
            let packetTransactionId = { () -> DWord? in
                switch packet {
                case let startData as StartDataPacket: return startData.transactionId
                case let data as DataPacket: return data.transactionId
                case let endData as EndDataPacket: return endData.transactionId
                case let response as CommandResponsePacket: return response.code != .okay ? nil : response.transactionId
                default: return nil
                }
            }()
            let viewfinderTransactionId = (packetStream as? InputOutputPacketStream)?.lastViewfinderRequest
            
            if packetTransactionId == nil || viewfinderTransactionId == nil || packetTransactionId != viewfinderTransactionId {
                Logger.log(message: "RECV: \(packet.debugDescription)", category: "PTPIPClient", level: .debug)
                os_log("RECV: %@", log: ptpClientLog, type: .debug, "\(packet.debugDescription)")
            }
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
        
        //print("handleCommandResponsePacket A")

        
        // Need to catch this, as sometimes cameras send invalid command responses, but sometimes they just
        // come through in multiple bundles, so we wait and augment them with further data
        guard !packet.awaitingFurtherData else {
            return
        }
        
        //print("handleCommandResponsePacket B")
        
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
    
    internal var dataContainers: [DWord : PTPIPClient.DataContainer] = [:]
        
}



//MARK: - StreamDelegate implementation

extension PTPIPClientNext: PTPPacketStreamDelegate {
    
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

extension PTPIPClientNext {
    func hasPendingCommands() -> Bool {
        for priority in PendingCommandPriority.allCases {
            if pendingCommandPackets[priority]?.count ?? 0 > 0 {
                return true
            }
        }
        
        return false
    }

    func removeFirstPendingCommand() -> PendingCommandRequest {
        for priority in PendingCommandPriority.allCases {
            if pendingCommandPackets[priority]?.count ?? 0 > 0 {
                return pendingCommandPackets[priority]!.removeFirst()
            }
        }
        
        fatalError("Cannot dequeue from an empty pending command queue")
    }
    
    func debugPendingCommandQueue() -> String {
        return ""
        //count: \(self.pendingCommandPackets.count) \(self.pendingCommandPackets.map { $0.packet.commandCode })
    }
}

enum PTPIPClientNextError: Error {
    case invalidResponse
    case failedToCreateStreamsToHost
    case socketClosed
}
