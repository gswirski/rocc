
//
//  SonyPTPIPCamera.swift
//  Rocc
//
//  Created by Simon Mitchell on 02/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation
import os.log

internal final class CanonPTPIPDevice: SonyCamera {
    
    let log = OSLog(subsystem: "com.yellow-brick-bear.rocc", category: "SonyPTPIPCamera")
    
    var ipAddress: sockaddr_in? = nil
    
    var apiVersion: String? = nil
    
    var baseURL: URL?
    
    var manufacturer: String
    
    var name: String?
    
    var model: String? = nil
    
    var firmwareVersion: String? = nil
    
    public var latestFirmwareVersion: String? {
        return modelEnum?.latestFirmwareVersion
    }
    
    var remoteAppVersion: String? = nil
    
    var latestRemoteAppVersion: String? = nil

    var eventVersion: String? {
        return "2.0"
    }
    
    var lensModelName: String? = nil
    
    var onEventAvailable: (() -> Void)?
    
    var onDisconnected: (() -> Void)?
    
    var zoomingDirection: Zoom.Direction?
    
    var highFrameRateCallback: ((Result<HighFrameRateCapture.Status, Error>) -> Void)?
        
    var eventPollingMode: PollingMode {
        guard let deviceInfo = deviceInfo else { return .timed }
        return deviceInfo.supportedEventCodes.contains(.propertyChanged) ? .cameraDriven : .timed
    }
    
    var connectionMode: ConnectionMode = .remoteControl
    
    private var cachedPTPIPClient: PTPIPClient?
    
    var ptpIPClient: PTPIPClient? {
        get {
            if let cachedPTPIPClient = cachedPTPIPClient {
                return cachedPTPIPClient
            }
            guard let stream = InputOutputPacketStream(camera: self, port: 15740) else {
                return nil
            }
            cachedPTPIPClient = PTPIPClient(camera: self, packetStream: stream)
            return cachedPTPIPClient
        }
        set {
            cachedPTPIPClient = newValue
        }
    }
    
    
    //MARK: - Initialisation -
    
    override init?(dictionary: [AnyHashable : Any]) {
        manufacturer = dictionary["manufacturer"] as? String ?? "Sony"
        
        super.init(dictionary: dictionary)
        
        let _name = dictionary["friendlyName"] as? String
        let _modelEnum: SonyCamera.Model?
        if let _name = _name {
            _modelEnum = SonyCamera.Model(rawValue: _name)
        } else {
            _modelEnum = nil
        }
                
        name = _modelEnum?.friendlyName ?? _name
        manufacturer = dictionary["manufacturer"] as? String ?? "Sony"
                
        modelEnum = _modelEnum
        model = modelEnum?.friendlyName
    }
    
    var isConnected: Bool = false
    
    var deviceInfo: PTP.DeviceInfo?

    /// The last set of `PTPDeviceProperty`s that we received from the camera
    /// retained so we can avoid asking the camera for the full array every time
    /// we need to fetch an event
    var lastAllDeviceProps: [PTPDeviceProperty]?
    
    var lastEventPacket: EventPacket?
    
    var lastEvent: CameraEvent?
    
    var lastStillCaptureModes: (available: [SonyStillCaptureMode], supported: [SonyStillCaptureMode])?
    
    var imageURLs: [ShootingMode : [URL]] = [:]
        
    override func update(with deviceInfo: SonyDeviceInfo?) {
        name = modelEnum == nil ? name : (deviceInfo?.model?.friendlyName ?? name)
        modelEnum = deviceInfo?.model ?? modelEnum
        if let modelEnum = deviceInfo?.model {
            model = modelEnum.friendlyName
        }
        lensModelName = deviceInfo?.lensModelName
        firmwareVersion = deviceInfo?.firmwareVersion
    }
    
    //MARK: - Handshake methods -
    
    private func sendStartSessionPacket(completion: @escaping CanonPTPIPDevice.ConnectedCompletion) {
        
        // First argument here is the session ID.
        let packet = Packet.commandRequestPacket(
            code: .openSession,
            arguments: [0x00000041],
            transactionId: ptpIPClient?.getNextTransactionId() ?? 0
        )
        ptpIPClient?.sendCommandRequestPacket(packet, callback: { [weak self] (response) in
            guard response.code == .okay else {
                completion(PTPError.commandRequestFailed(response.code), false)
                return
            }
            self?.setRemoteMode(completion: completion)
        }, callCallbackForAnyResponse: true)
    }
    
    private func setRemoteMode(completion: @escaping CanonPTPIPDevice.ConnectedCompletion) {
        let packet = Packet.commandRequestPacket(code: .canonSetRemoteMode, arguments: [0x00000015], transactionId: ptpIPClient?.getNextTransactionId() ?? 1)
        
        ptpIPClient?.sendCommandRequestPacket(packet, callback: { [weak self] (response) in
            guard response.code == .okay else {
                completion(PTPError.commandRequestFailed(response.code), false)
                return
            }
            self?.unknownConnectionCommand(completion: completion)

        })
    }
    
    private func unknownConnectionCommand(completion: @escaping CanonPTPIPDevice.ConnectedCompletion) {
        let packet = Packet.commandRequestPacket(code: .canonUnknownInitCommand, arguments: nil, transactionId: ptpIPClient?.getNextTransactionId() ?? 1)
        
        ptpIPClient?.sendCommandRequestPacket(packet, callback: { [weak self] (response) in
            guard response.code == .okay else {
                completion(PTPError.commandRequestFailed(response.code), false)
                return
            }
            self?.setEventMode(completion: completion)

        })

    }
    
    private func setEventMode(completion: @escaping CanonPTPIPDevice.ConnectedCompletion) {
        let packet = Packet.commandRequestPacket(code: .canonSetEventMode, arguments: [0x00000002], transactionId: ptpIPClient?.getNextTransactionId() ?? 1)
        
        ptpIPClient?.sendCommandRequestPacket(packet, callback: { [weak self] (response) in
            guard response.code == .okay else {
                completion(PTPError.commandRequestFailed(response.code), false)
                return
            }
            self?.performInitialEventFetch(completion: completion)

        })

    }

    private func performCloseSession(completion: @escaping CanonPTPIPDevice.ConnectedCompletion) {
        let packet = Packet.commandRequestPacket(code: .closeSession, arguments: nil, transactionId: ptpIPClient?.getNextTransactionId() ?? 1)
        ptpIPClient?.sendCommandRequestPacket(packet, callback: { (response) in
            completion(PTPError.anotherSessionOpen, false)
        }, callCallbackForAnyResponse: true)
    }
    
    
    private func performInitialEventFetch(completion: @escaping CanonPTPIPDevice.ConnectedCompletion) {
        self.performFunction(Event.get, payload: nil, callback: { [weak self] (error, event) in
            self?.lastEvent = event
            // Can ignore errors as we don't really require this event for the connection process to complete!
            completion(nil, false)
        })
    }
    
    func getDevicePropDescriptionsFor(propCodes: [PTP.DeviceProperty.Code], callback: @escaping PTPIPClient.AllDevicePropertyDescriptionsCompletion) {
        
        guard let ptpIPClient = ptpIPClient else { return }
        
        if deviceInfo?.supportedOperations.contains(.getAllDevicePropData) ?? false {
            
            ptpIPClient.getAllDevicePropDesc(callback: { (result) in
                switch result {
                case .success(let properties):
                    let returnProperties = properties.filter({ propCodes.contains($0.code) })
                    guard !returnProperties.isEmpty else {
                        callback(Result.failure(PTPError.propCodeNotFound))
                        return
                    }
                    callback(Result.success(returnProperties))
                case .failure(let error):
                    callback(Result.failure(error))
                }
            })
            
        } else if deviceInfo?.supportedOperations.contains(.sonyGetDevicePropDesc) ?? false {
            
            var remainingCodes = propCodes
            var returnProperties: [PTPDeviceProperty] = []
            
            propCodes.forEach { (propCode) in
                
                let packet = Packet.commandRequestPacket(code: .sonyGetDevicePropDesc, arguments: [DWord(propCode.rawValue)], transactionId: ptpIPClient.getNextTransactionId())
                ptpIPClient.awaitDataFor(transactionId: packet.transactionId) { (dataResult) in
                    
                    remainingCodes.removeAll(where: { $0 == propCode })
                    
                    switch dataResult {
                    case .success(let data):
                        guard let property = data.data.getDeviceProperty(at: 0) else {
                            callback(Result.failure(PTPIPClientError.invalidResponse))
                            return
                        }
                        returnProperties.append(property)
                    case .failure(_):
                        break
                    }
                    
                    guard remainingCodes.isEmpty else { return }
                    callback(returnProperties.count == propCodes.count ? Result.success(returnProperties) : Result.failure(PTPError.propCodeNotFound))
                }
                ptpIPClient.sendCommandRequestPacket(packet, callback: nil)
            }
            
            
        } else if deviceInfo?.supportedOperations.contains(.getDevicePropDesc) ?? false {
            
            var remainingCodes = propCodes
            var returnProperties: [PTPDeviceProperty] = []
            
            propCodes.forEach { (propCode) in
                
                ptpIPClient.getDevicePropDescFor(propCode: propCode) { (result) in
                    
                    remainingCodes.removeAll(where: { $0 == propCode })

                    switch result {
                    case .success(let property):
                        returnProperties.append(property)
                    case .failure(_):
                        break
                    }
                    
                    guard remainingCodes.isEmpty else { return }
                    callback(returnProperties.count == propCodes.count ? Result.success(returnProperties) : Result.failure(PTPError.propCodeNotFound))
                }
            }
                        
        } else {
            
            callback(Result.failure(PTPError.operationNotSupported))
        }
    }
    
    func getDevicePropDescriptionFor(propCode: PTP.DeviceProperty.Code,  callback: @escaping PTPIPClient.DevicePropertyDescriptionCompletion) {
        
        guard let ptpIPClient = ptpIPClient else { return }
        
        if deviceInfo?.supportedOperations.contains(.getAllDevicePropData) ?? false {
            
            ptpIPClient.getAllDevicePropDesc(callback: { (result) in
                switch result {
                case .success(let properties):
                    guard let property = properties.first(where: { $0.code == propCode }) else {
                        callback(Result.failure(PTPError.propCodeNotFound))
                        return
                    }
                    callback(Result.success(property))
                case .failure(let error):
                    callback(Result.failure(error))
                }
            })
            
        } else if deviceInfo?.supportedOperations.contains(.sonyGetDevicePropDesc) ?? false {
            
            let packet = Packet.commandRequestPacket(code: .sonyGetDevicePropDesc, arguments: [DWord(propCode.rawValue)], transactionId: ptpIPClient.getNextTransactionId())
            ptpIPClient.awaitDataFor(transactionId: packet.transactionId) { (dataResult) in
                switch dataResult {
                case .success(let data):
                    guard let property = data.data.getDeviceProperty(at: 0) else {
                        callback(Result.failure(PTPIPClientError.invalidResponse))
                        return
                    }
                    callback(Result.success(property))
                case .failure(let error):
                    callback(Result.failure(error))
                }
            }
            ptpIPClient.sendCommandRequestPacket(packet, callback: nil)
            
        } else if deviceInfo?.supportedOperations.contains(.getDevicePropDesc) ?? false {
            
            ptpIPClient.getDevicePropDescFor(propCode: propCode, callback: callback)
            
        } else {
            
            callback(Result.failure(PTPError.operationNotSupported))
        }
    }
    
    var isAwaitingObject: Bool = false
    
    var awaitingObjectId: DWord?
    
    fileprivate func handlePTPIPEvent(_ event: EventPacket) {
        
        lastEventPacket = event
        
        switch event.code {
        case .propertyChanged:
            onEventAvailable?()
        case .objectAdded:
            guard let objectID = event.variables?.first else {
                return
            }
            if isAwaitingObject {
                awaitingObjectId = objectID
            }
            Logger.log(message: "Handling \"Object Added\" event, initiating transfer", category: "SonyPTPIPCamera", level: .debug)
            os_log("Handling \"Object Added\" event, initiating transfer. Awaiting object: %@", log: self.log, type: .debug, isAwaitingObject ? "true" : "false")
            handleObjectId(objectID: objectID, shootingMode: lastEvent?.shootMode?.current ?? .photo) { (result) in
                
            }
            break
        case .objectRemoved:
            // If object was removed, we are done with capture
            break
        default:
            break
        }
    }
    
    enum PTPError: Error {
        case commandRequestFailed(CommandResponsePacket.Code)
        case fetchDeviceInfoFailed
        case fetchSdioExtDeviceInfoFailed
        case deviceInfoNotAvailable
        case objectNotFound
        case propCodeNotFound
        case anotherSessionOpen
        case operationNotSupported
    }
}

//MARK: - Camera protocol conformance -

extension CanonPTPIPDevice: Camera {
    
    var isInBeta: Bool {
        return false
    }
        
    func connect(completion: @escaping CanonPTPIPDevice.ConnectedCompletion) {
        lastEvent = nil
        lastEventPacket = nil
        lastStillCaptureModes = nil
        lastAllDeviceProps = nil
        zoomingDirection = nil
        highFrameRateCallback = nil
        
        // Set these first because tests that rely on these being set
        // run synchronously!
        ptpIPClient?.onEvent = { [weak self] (event) in
            self?.handlePTPIPEvent(event)
        }
        ptpIPClient?.onDisconnect = { [weak self] in
            self?.onDisconnected?()
        }

        retry(work: { [weak self] (anotherAttemptMaybeSuccessful, attemptNumber) in
            guard let self = self else { return }

            Logger.log(message: "PTP/IP Connection attempt: \(attemptNumber)", category: "SonyPTPIPCamera", level: .debug)
            os_log("PTP/IP Connection attempt: %d", log: self.log, type: .debug, attemptNumber)

            let retriableCompletion: CanonPTPIPDevice.ConnectedCompletion = { (_ error: Error?, _ transferMode: Bool) in
                var retriable = false

                if let ptpError = error as? PTPError {
                    switch ptpError {
                    case .anotherSessionOpen, .operationNotSupported:
                        retriable = true
                    default:
                        retriable = false
                    }
                }

                if !anotherAttemptMaybeSuccessful(retriable) {
                    completion(error, transferMode)
                }
            }
            self.ptpIPClient?.connect(callback: { [weak self] (error) in
                self?.sendStartSessionPacket(completion: retriableCompletion)
            })
        }, attempts: 3)
    }

    func disconnect(completion: @escaping DisconnectedCompletion) {
        ptpIPClient?.onDisconnect = nil
        ptpIPClient?.disconnect()
        completion(nil)
    }
    
    func makeFunctionAvailable<T>(_ function: T, callback: @escaping ((Error?) -> Void)) where T : CameraFunction {
        
        switch function.function {
        case .startContinuousShooting:
            
            setShutterSpeedAwayFromBulbIfRequired { [weak self] (_) in
                
                guard let self = self else { return }
                
                // On PTP IP cameras still capture mode gives us both continuous shooting speed, and it's mode too
                self.getDevicePropDescriptionFor(propCode: .stillCaptureMode, callback: { [weak self] (result) in
                    
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let property):
                        
                        let event = CameraEvent.fromSonyDeviceProperties([property]).event
                        guard let firstMode = event.continuousShootingMode?.available.first(where: { $0 != .single }) ?? event.continuousShootingMode?.available.first else {
                            callback(nil)
                            return
                        }
                        
                        self.performFunction(ContinuousCapture.Mode.set, payload: firstMode) { [weak self] (error, _) in

                            guard error == nil else {
                                callback(error)
                                return
                            }
                            
                            guard let self = self else { return }
                            
                            guard let firstSpeed = event.continuousShootingSpeed?.available.first else {
                                callback(nil)
                                return
                            }
                            
                            self.performFunction(ContinuousCapture.Speed.set, payload: firstSpeed) { (error, _) in
                                callback(error)
                            }
                        }
                    case .failure(let error):
                        callback(error)
                    }
                })
            }
        case .startBulbCapture:
            performFunction(Shutter.Speed.set, payload: ShutterSpeed.bulb) { [weak self] (shutterSpeedError, _) in
                guard shutterSpeedError == nil else {
                    callback(shutterSpeedError)
                    return
                }
                // We need to do this otherwise the camera can get stuck in continuous shooting mode!
                self?.performFunction(ShootMode.set, payload: .photo) { (_, _) in
                    callback(nil)
                }
            }
        case .takePicture:
            setShutterSpeedAwayFromBulbIfRequired() { [weak self] (_) in
                self?.performFunction(ShootMode.set, payload: .photo) { (_, _) in
                    callback(nil)
                }
            }
        case .startIntervalStillRecording:
            setShutterSpeedAwayFromBulbIfRequired() { [weak self] (_) in
                self?.setToShootModeIfRequired(.interval, callback)
            }
        case .startAudioRecording:
            setShutterSpeedAwayFromBulbIfRequired() { [weak self] (_) in
                self?.setToShootModeIfRequired(.audio, callback)
            }
        case .startVideoRecording:
            setShutterSpeedAwayFromBulbIfRequired() { [weak self] (_) in
                self?.setToShootModeIfRequired(.video, callback)
            }
        case .startLoopRecording:
            setShutterSpeedAwayFromBulbIfRequired() { [weak self] (_) in
                self?.setToShootModeIfRequired(.loop, callback)
            }
        case .recordHighFrameRateCapture:
            setShutterSpeedAwayFromBulbIfRequired() { [weak self] (_) in
                self?.setToShootModeIfRequired(.highFrameRate, callback)
            }
        case .startContinuousBracketShooting:
            setShutterSpeedAwayFromBulbIfRequired { [weak self] (_) in
                self?.setToShootModeIfRequired(.continuousBracket, callback)
            }
        case .takeSingleBracketShot:
            setShutterSpeedAwayFromBulbIfRequired { [weak self] (_) in
                self?.setToShootModeIfRequired(.singleBracket, callback)
            }
        default:
            callback(nil)
        }
    }
    
    func bestStillCaptureMode(for shootMode: ShootingMode) -> SonyStillCaptureMode? {
                
        switch shootMode {
        case .video:
            return .single
        case .audio, .loop, .interval, .highFrameRate:
            return nil
        case .photo, .timelapse, .bulb:
            return .single
        case .continuous:
            guard let continuousShootingModes = lastStillCaptureModes?.available.filter({
                $0.shootMode == .continuous
            }) else {
                return .continuous
            }
            return continuousShootingModes.first
        case .singleBracket:
            return lastStillCaptureModes?.available.filter({
                $0.shootMode == .singleBracket
            }).first
        case .continuousBracket:
            return lastStillCaptureModes?.available.filter({
                $0.shootMode == .continuousBracket
            }).first
        }
    }
    
    func bestExposureProgrammeModes(for shootMode: ShootingMode, currentExposureProgrammeMode: Exposure.Mode.Value?) -> [Exposure.Mode.Value]? {
        
        var modes: [Exposure.Mode.Value]?
        let defaultModes: [Exposure.Mode.Value] = [.intelligentAuto, .programmedAuto, .aperturePriority, .shutterPriority, .manual, .superiorAuto, .slowAndQuickProgrammedAuto, .slowAndQuickAperturePriority, .slowAndQuickShutterPriority, .slowAndQuickManual]
        
        // For Video -> Photo or Photo -> Video there are equivalents, so Aperture Priority has Video Aperture Priority e.t.c. so we should prioritise these...
        switch shootMode {
        case .highFrameRate:
            let defaultHFRModes: [Exposure.Mode.Value] = [.highFrameRateProgrammedAuto, .highFrameRateAperturePriority, .highFrameRateShutterPriority, .highFrameRateManual]
            switch currentExposureProgrammeMode {
            case .aperturePriority, .slowAndQuickAperturePriority, .videoAperturePriority:
                modes = defaultHFRModes.bringingToFront(.videoAperturePriority)
            case .programmedAuto, .intelligentAuto, .slowAndQuickProgrammedAuto, .videoProgrammedAuto:
                modes = defaultHFRModes.bringingToFront(.videoProgrammedAuto)
            case .shutterPriority, .slowAndQuickShutterPriority, .videoShutterPriority:
                modes = defaultHFRModes.bringingToFront(.videoShutterPriority)
            case .manual, .slowAndQuickManual, .videoManual:
                modes = defaultHFRModes.bringingToFront(.videoManual)
            default:
                modes = defaultHFRModes
            }
        case .video:
            let defaultVideoModes: [Exposure.Mode.Value] = [.videoProgrammedAuto, .videoAperturePriority, .videoShutterPriority, .videoManual]
            switch currentExposureProgrammeMode {
            case .aperturePriority, .slowAndQuickAperturePriority, .highFrameRateAperturePriority:
                modes = defaultVideoModes.bringingToFront(.videoAperturePriority)
            case .programmedAuto, .intelligentAuto, .slowAndQuickProgrammedAuto, .highFrameRateProgrammedAuto:
                modes = defaultVideoModes.bringingToFront(.videoProgrammedAuto)
            case .shutterPriority, .slowAndQuickShutterPriority, .highFrameRateShutterPriority:
                modes = defaultVideoModes.bringingToFront(.videoShutterPriority)
            case .manual, .slowAndQuickManual, .highFrameRateManual:
                modes = defaultVideoModes.bringingToFront(.videoManual)
            default:
                modes = defaultVideoModes
            }
        case .photo, .timelapse, .singleBracket, .continuousBracket:
            switch currentExposureProgrammeMode {
            case .videoShutterPriority:
                modes = defaultModes.bringingToFront(.slowAndQuickShutterPriority).bringingToFront(.shutterPriority)
            case .videoProgrammedAuto:
                modes = defaultModes.bringingToFront(.intelligentAuto).bringingToFront(.superiorAuto).bringingToFront(.slowAndQuickProgrammedAuto).bringingToFront(.programmedAuto)
            case .videoAperturePriority:
                modes = defaultModes.bringingToFront(.slowAndQuickAperturePriority).bringingToFront(.aperturePriority)
            case .videoManual:
                modes = defaultModes.bringingToFront(.slowAndQuickManual).bringingToFront(.manual)
            case .some(let currentMode):
                modes = defaultModes.bringingToFront(currentMode)
            default:
                // Don't need to worry about sorting here, as we'll already be in the required mode
                modes = defaultModes
            }
            break
        case .bulb:
            // If we're in BULB then we need to return either M or Shutter Priority
            switch currentExposureProgrammeMode {
            case .videoShutterPriority:
                modes = [.shutterPriority, .slowAndQuickShutterPriority, .manual, .slowAndQuickManual]
            case .videoManual:
                modes = [.manual, .slowAndQuickManual, .shutterPriority, .slowAndQuickShutterPriority]
            default:
                modes = [.shutterPriority, .slowAndQuickShutterPriority, .manual, .slowAndQuickManual]
            }
        default:
            return nil
        }
        
        if let availableModes = lastEvent?.exposureMode?.available {
            modes = modes?.filter({ availableModes.contains($0) })
        }
        
        return modes
    }
    
    private func setToExposureProgrammgeModeIfRequired(for shootMode: ShootingMode, _ completion: @escaping ((Error?) -> Void)) {
        
        guard let exposureProgrammeModes = self.bestExposureProgrammeModes(for: shootMode, currentExposureProgrammeMode: self.lastEvent?.exposureMode?.current), let firstMode = exposureProgrammeModes.first else {
            completion(nil)
            return
        }
        // If our preffered exposure programme modes already contains the current one, we don't need to do anything
        if let current = lastEvent?.exposureMode?.current, exposureProgrammeModes.contains(current) {
            completion(nil)
            return
        }
        
        // Make sure this is available, as it isn't always!
        isFunctionAvailable(Exposure.Mode.set) { [weak self] (available, _, _) in
            guard let self = self else {
                completion(nil)
                return
            }
            guard let _available = available, _available else {
                completion(nil)
                return
            }
            self.setExposureProgrammeMode(firstMode, completion)
        }
    }
    
    private func setToShootModeIfRequired(_ shootMode: ShootingMode, _ completion: @escaping ((Error?) -> Void)) {
        
        // Last shoot mode should be up to date so do a quick check if we're already in the correct shoot mode
        guard lastEvent?.shootMode?.current != shootMode else {
            completion(nil)
            return
        }
        
        guard let stillCaptureMode = bestStillCaptureMode(for: shootMode) else {
            setToExposureProgrammgeModeIfRequired(for: shootMode, completion)
            return
        }
        
        setStillCaptureMode(stillCaptureMode) { [weak self] (error) in
            guard let self = self, error == nil else {
                completion(error)
                return
            }
            self.setToExposureProgrammgeModeIfRequired(for: shootMode, completion)
        }
    }
    
    func setExposureProgrammeMode(_ mode: Exposure.Mode.Value, _ completion: @escaping ((Error?) -> Void)) {
        
        ptpIPClient?.sendSetControlDeviceAValue(
            PTP.DeviceProperty.Value(
                code: .exposureProgramMode,
                type: .uint32,
                value: mode.sonyPTPValue
            ),
            callback: { (response) in
                completion(response.code.isError ? PTPError.commandRequestFailed(response.code) : nil)
            }
        )
    }
    
    func setStillCaptureMode(_ mode: SonyStillCaptureMode, _ completion: @escaping ((Error?) -> Void)) {
        
        ptpIPClient?.sendSetControlDeviceAValue(
            PTP.DeviceProperty.Value(
                code: .stillCaptureMode,
                type: .uint32,
                value: mode.rawValue
            ),
            callback: { (response) in
                completion(response.code.isError ? PTPError.commandRequestFailed(response.code) : nil)
            }
        )
    }
    
    private func setShutterSpeedAwayFromBulbIfRequired(_ callback: @escaping ((Error?) -> Void)) {
        
        // We need to do this otherwise the camera can get stuck in continuous shooting mode!
        // If the shutter speed is BULB then we need to set it to something else!
        guard self.lastEvent?.shutterSpeed?.current.isBulb == true else {
            callback(nil)
            return
        }
        
        // Get available shutter speeds
        getDevicePropDescriptionFor(propCode: .shutterSpeed) { [weak self] (result) in
            
            guard let self = self else { return }
            
            switch result {
            case .success(let property):
                let event = CameraEvent.fromSonyDeviceProperties([property]).event
                guard let firstNonBulbShutterSpeed = event.shutterSpeed?.available.first(where: { !$0.isBulb }) else {
                    callback(nil)
                    return
                }
                // Set shutter speed to non-bulb
                self.performFunction(Shutter.Speed.set, payload: firstNonBulbShutterSpeed) { (error, _) in
                    callback(error)
                }
            case .failure(let error):
                callback(error)
            }
        }
    }
    
    func loadFilesToTransfer(callback: @escaping ((Error?, [File]?) -> Void)) {
        
    }
    
    func finishTransfer(callback: @escaping ((Error?) -> Void)) {
        
    }
    
    func handleEvent(event: CameraEvent) {
        defer {
            lastEvent = event
        }
        guard let highFrameRateStatus = event.highFrameRateCaptureStatus, highFrameRateStatus != lastEvent?.highFrameRateCaptureStatus else { return }
        highFrameRateCallback?(Result.success(highFrameRateStatus))
    }
}
