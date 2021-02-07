//
//  SonyPTPIPCamera+PerformFunction.swift
//  Rocc
//
//  Created by Simon Mitchell on 17/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation
import os.log

extension CanonPTPIPDevice {
    
    typealias AllDevicePropertyDescriptionsCompletion = (_ result: Result<[PTPDeviceProperty], Error>) -> Void
    
    func parseEvent(data eventData: ByteBuffer) -> [PTPDeviceProperty] {
        let dataSize = eventData.length
        var pointer: UInt = 0
        
        if allProperties == nil {
            var apertureField = PTP.DeviceProperty.Enum()
            apertureField.type = .uint32
            apertureField.code = .fNumber
            apertureField.getSetAvailable = .getSet
            apertureField.getSetSupported = .getSet
            apertureField.length = 4
            
            var shutterSpeedField = PTP.DeviceProperty.Enum()
            shutterSpeedField.type = .uint32
            shutterSpeedField.code = .shutterSpeed
            shutterSpeedField.getSetAvailable = .getSet
            shutterSpeedField.getSetSupported = .getSet
            shutterSpeedField.length = 4
            
            var isoField = PTP.DeviceProperty.Enum()
            isoField.type = .uint32
            isoField.code = .ISO
            isoField.getSetAvailable = .getSet
            isoField.getSetSupported = .getSet
            isoField.length = 4
            
            var exposureCompensationField = PTP.DeviceProperty.Enum()
            exposureCompensationField.type = .uint32
            exposureCompensationField.code = .exposureBiasCompensation
            exposureCompensationField.getSetAvailable = .getSet
            exposureCompensationField.getSetSupported = .getSet
            exposureCompensationField.length = 4

            var autoExposureMode = PTP.DeviceProperty.Enum()
            autoExposureMode.type = .uint32
            autoExposureMode.code = .exposureProgramMode
            autoExposureMode.getSetAvailable = .getSet
            autoExposureMode.getSetSupported = .getSet
            autoExposureMode.length = 4
            
            allProperties = [
                .fNumber: apertureField,
                .shutterSpeed: shutterSpeedField,
                .ISO: isoField,
                .exposureBiasCompensation: exposureCompensationField,
                .exposureProgramModeControl: autoExposureMode
            ]
        }
        
        guard var allProperties = allProperties else {
            fatalError("This should never happened. We just initialized all properties")
        }
        
        var apertureField = allProperties[.fNumber] as! PTP.DeviceProperty.Enum
        var shutterSpeedField = allProperties[.shutterSpeed] as! PTP.DeviceProperty.Enum
        var isoField = allProperties[.ISO] as! PTP.DeviceProperty.Enum
        var exposureCompensationField = allProperties[.exposureBiasCompensation] as! PTP.DeviceProperty.Enum
        var autoExposureMode = allProperties[.exposureProgramModeControl] as! PTP.DeviceProperty.Enum

        while (pointer + 8 < dataSize) {
            var size: DWord? = eventData[dWord: pointer]
            var type: DWord? = eventData[dWord: pointer + 4]
            
            var propType = CanonPropType(rawValue: type!)
            
            switch propType {
            case .PTP_EC_CANON_EOS_CameraStatusChanged:
                let value = eventData[dWord: pointer + 8]!
                print("Received property \(propType) \(value)")
            case .PTP_EC_CANON_EOS_PropValueChanged:
                let subType = CanonSubPropType(rawValue: eventData[dWord: pointer + 8]!)
                
                switch subType {
                case .PTP_DPC_CANON_EOS_Aperture:
                    let value = eventData[dWord: pointer + 12]
                    apertureField.currentValue = value!
                    apertureField.factoryValue = value!
                    
                    print("Received property \(propType) \(subType) size:\(size) \(value)")
                case .PTP_DPC_CANON_EOS_ShutterSpeed:
                    let value = eventData[dWord: pointer + 12]
                    shutterSpeedField.currentValue = value!
                    shutterSpeedField.factoryValue = value!
                    
                    print("Received property \(propType) \(subType) size:\(size) \(value)")
                case .PTP_DPC_CANON_EOS_ISOSpeed:
                    let value = eventData[dWord: pointer + 12]
                    isoField.currentValue = value!
                    isoField.factoryValue = value!
                    
                    print("Received property \(propType) \(subType) size:\(size) \(value)")
                case .PTP_DPC_CANON_EOS_ExpCompensation:
                    let value = eventData[dWord: pointer + 12]
                    exposureCompensationField.currentValue = value!
                    exposureCompensationField.factoryValue = value!
                    
                    print("Received property \(propType) \(subType) size:\(size) \(value)")
                case .PTP_DPC_CANON_EOS_AutoExposureMode:
                    let value = eventData[dWord: pointer + 12]
                    autoExposureMode.currentValue = value!
                    autoExposureMode.factoryValue = value!
                    
                    print("Received property \(propType) \(subType) size:\(size) \(value)")

                default:
                    /*let bytes = eventData.sliced(Int(pointer), Int(pointer) + Int(size!))
                    print("Received property \(propType) (\(type)) \(subType) size:\(size) bytes: \(bytes.toHex)")*/
                    break
                }
            case .PTP_EC_CANON_EOS_AvailListChanged:
                let subType = CanonSubPropType(rawValue: eventData[dWord: pointer + 8]!)
                let count = eventData[dWord: pointer + 16]!
                
                let values = (0..<count).map { (index) -> DWord in
                    let offset = 16 + 4 * UInt(index + 1)
                    return eventData[dWord: pointer + offset]!
                }
                
                switch subType {
                case .PTP_DPC_CANON_EOS_Aperture:
                    apertureField.available = values
                    apertureField.supported = values
                    print("Received property values: \(propType) \(subType) \(values)")
                case .PTP_DPC_CANON_EOS_ShutterSpeed:
                    shutterSpeedField.available = values
                    shutterSpeedField.supported = values
                    print("Received property values: \(propType) \(subType) \(values)")
                case .PTP_DPC_CANON_EOS_ISOSpeed:
                    isoField.available = values
                    isoField.supported = values
                    print("Received property values: \(propType) \(subType) \(values)")
                case .PTP_DPC_CANON_EOS_ExpCompensation:
                    exposureCompensationField.available = values
                    exposureCompensationField.supported = values
                    print("Received property values: \(propType) \(subType) \(values)")
                default:
                    /*let bytes = eventData.sliced(Int(pointer), Int(pointer) + Int(size!))
                    print("Received property values \(type) size:\(size) bytes: \(bytes.toHex)")*/
                    break
                }
            case .PTP_EC_CANON_EOS_OLCInfoChanged:
                let len = eventData[dWord: pointer + 8]!
                lastOLCInfoChanged = eventData.sliced(Int(pointer) + 8, Int(pointer) + 8 + Int(len))
                
                let mask = eventData[word: pointer + 12]!
                print("Received property OLC mask \(mask): \(lastOLCInfoChanged)")

                var olcOffset: UInt = 0
                if (mask & 0x0001) != 0 {
                    olcOffset += 2
                }
                if (mask & 0x0002) != 0 {
                    let value = eventData[word: pointer + 16 + olcOffset + 5]!
                    print("Received property OLC Shutter Speed: \(propType) (value)")
                }
 
            case .PTP_EC_CANON_EOS_ObjectAddedEx, .PTP_EC_CANON_EOS_ObjectAddedEx64:
                
                lastObjectAdded = eventData.sliced(Int(pointer), Int(pointer) + Int(size!))

                let objectID = eventData[dWord: pointer + 8]!
                let storageID = eventData[dWord: pointer + 12]!
                let OFC = eventData[dWord: pointer + 16]!
                let size = eventData[dWord: pointer + 28]!
                let parent = eventData[dWord: pointer + 36]!
                
                print("Received property \(propType) objectID:\(objectID) parent \(parent) storageID \(storageID) OFC \(OFC) size \(size)")
                
            default:
                /*if Int(size!) < 300 {
                    let bytes = eventData.sliced(Int(pointer), Int(pointer) + Int(size!))
                    print("Received property \(type) size:\(size) bytes: \(bytes.toHex)")
                } else {
                    print("Received property \(type) size:\(size)")
                }*/
                break
            }
            
            
            pointer += UInt(size!)
        }
        
        allProperties[.fNumber] = apertureField
        allProperties[.shutterSpeed] = shutterSpeedField
        allProperties[.ISO] = isoField
        allProperties[.exposureBiasCompensation] = exposureCompensationField
        allProperties[.exposureProgramModeControl] = autoExposureMode
        
        self.allProperties = allProperties

        return Array(allProperties.values)
    }
    
    func getEvent(
        callback: @escaping AllDevicePropertyDescriptionsCompletion
    ) {
        
        let packet = CommandRequestPacketArguments(commandCode: .canonGetEvent, arguments: nil)
        ptpIPClient?.sendCommandRequestPacket(packet, responseCallback: nil, dataCallback: { (dataResult) in
            switch dataResult {
            case .success(let data):
                callback(Result.success(self.parseEvent(data: data.data)))
            case .failure(let error):
                callback(Result.failure(error))
            }

        })
    }

    
    func performFunction<T>(_ function: T, payload: T.SendType?, callback: @escaping ((Error?, T.ReturnType?) -> Void)) where T : CameraFunction {
        
        switch function.function {
        case .getEvent:
            
            guard !imageURLs.isEmpty, var lastEvent = lastEvent else {
                getEvent { (result) in
                    switch result {
                    case .success(let properties):
                        print("received properties \(properties)")
                        
                        var exposureMode: (current: Exposure.Mode.Value, available: [Exposure.Mode.Value], supported: [Exposure.Mode.Value])?
                        var aperture: (current: Aperture.Value, available: [Aperture.Value], supported: [Aperture.Value])?
                        var shutterSpeed: (current: ShutterSpeed, available: [ShutterSpeed], supported: [ShutterSpeed])?
                        var iso: (current: ISO.Value, available: [ISO.Value], supported: [ISO.Value])?
                        var exposureCompensation: (current: Exposure.Compensation.Value, available: [Exposure.Compensation.Value], supported: [Exposure.Compensation.Value])?
                        
                        var availableFunctions: [_CameraFunction] = []
                        var supportedFunctions: [_CameraFunction] = []

                        properties.forEach { (deviceProperty) in
                            switch deviceProperty.getSetSupported {
                            case .get:
                                if let getFunction = deviceProperty.code.getFunction {
                                    supportedFunctions.append(getFunction)
                                }
                            case .getSet:
                                if let getFunction = deviceProperty.code.getFunction {
                                    supportedFunctions.append(getFunction)
                                }
                                if let setFunctions = deviceProperty.code.setFunctions {
                                    supportedFunctions.append(contentsOf: setFunctions)
                                }
                            default:
                                break
                            }
                            
                            switch deviceProperty.getSetAvailable {
                            case .get:
                                if let getFunction = deviceProperty.code.getFunction {
                                    availableFunctions.append(getFunction)
                                }
                            case .getSet:
                                if let getFunction = deviceProperty.code.getFunction {
                                    availableFunctions.append(getFunction)
                                }
                                if let setFunctions = deviceProperty.code.setFunctions {
                                    availableFunctions.append(contentsOf: setFunctions)
                                }
                            default:
                                break
                            }
                            
                            switch deviceProperty.code {
                            case .fNumber:
                                guard let enumProperty = deviceProperty as? PTP.DeviceProperty.Enum else {
                                    return
                                }
                                guard let value = Aperture.Value(canonValue: enumProperty.currentValue) else {
                                    return
                                }
                                
                                let available = enumProperty.available.compactMap { Aperture.Value(canonValue: $0) }
                                let supported = enumProperty.available.compactMap { Aperture.Value(canonValue: $0) }
                                
                                aperture = (value, available, supported)
                                break
                            case .shutterSpeed:
                                guard let enumProperty = deviceProperty as? PTP.DeviceProperty.Enum else {
                                    return
                                }
                                guard let value = ShutterSpeed(canonValue: enumProperty.currentValue) else {
                                    return
                                }
                                
                                let available = enumProperty.available.compactMap { ShutterSpeed(canonValue: $0) }
                                let supported = enumProperty.available.compactMap { ShutterSpeed(canonValue: $0) }
                                
                                shutterSpeed = (value, available, supported)
                                break
                            case .ISO:
                                guard let enumProperty = deviceProperty as? PTP.DeviceProperty.Enum else {
                                    return
                                }
                                guard let value = ISO.Value(canonValue: enumProperty.currentValue) else {
                                    return
                                }
                                
                                let available = enumProperty.available.compactMap { ISO.Value(canonValue: $0) }
                                let supported = enumProperty.available.compactMap { ISO.Value(canonValue: $0) }
                                
                                iso = (value, available, supported)
                                break
                            case .exposureBiasCompensation:
                                guard let enumProperty = deviceProperty as? PTP.DeviceProperty.Enum else {
                                    return
                                }
                                guard let value = Exposure.Compensation.Value(canonValue: enumProperty.currentValue) else {
                                    return
                                }
                                
                                let available = enumProperty.available.compactMap { Exposure.Compensation.Value(canonValue: $0) }
                                let supported = enumProperty.available.compactMap { Exposure.Compensation.Value(canonValue: $0) }
                                
                                exposureCompensation = (value, available, supported)
                                break
                            case .exposureProgramMode:
                                guard let enumProperty = deviceProperty as? PTP.DeviceProperty.Enum else {
                                    return
                                }
                                guard let value = Exposure.Mode.Value(canonValue: enumProperty.currentValue) else {
                                    return
                                }
                                
                                exposureMode = (value, [], [])
                                break

                            default:
                                break
                            }
                        }
                        
                        let event = CameraEvent(status: nil, liveViewInfo: nil, liveViewQuality: nil, zoomPosition: nil, availableFunctions: availableFunctions, supportedFunctions: supportedFunctions, postViewPictureURLs: nil, storageInformation: nil, beepMode: nil, function: nil, functionResult: false, videoQuality: nil, stillSizeInfo: nil, steadyMode: nil, viewAngle: nil, exposureMode: exposureMode, exposureModeDialControl: nil, exposureSettingsLockStatus: nil, postViewImageSize: nil, selfTimer: nil, shootMode: nil, exposureCompensation: exposureCompensation, flashMode: nil, aperture: aperture, focusMode: nil, iso: iso, isProgramShifted: nil, shutterSpeed: shutterSpeed, whiteBalance: nil, touchAF: nil, focusStatus: nil, zoomSetting: nil, stillQuality: nil, stillFormat: nil, continuousShootingMode: nil, continuousShootingSpeed: nil, continuousBracketedShootingBrackets: nil, singleBracketedShootingBrackets: nil, flipSetting: nil, scene: nil, intervalTime: nil, colorSetting: nil, videoFileFormat: nil, videoRecordingTime: nil, highFrameRateCaptureStatus: nil, infraredRemoteControl: nil, tvColorSystem: nil, trackingFocusStatus: nil, trackingFocus: nil, batteryInfo: nil, numberOfShots: nil, autoPowerOff: nil, loopRecordTime: nil, audioRecording: nil, windNoiseReduction: nil, bulbShootingUrl: nil, bulbCapturingTime: nil, bulbShootingURLS: nil)
                        callback(nil, event as? T.ReturnType)
                    case .failure(let error):
                        print("received error \(error)")
                        callback(error, nil)
                    }
                }
                
                /*ptpIPClient?.getAllDevicePropDesc(callback: { [weak self] (result) in
                    guard let self = self else { return }
                    switch result {
                    case .success(var properties):

                        if var lastProperties = self.lastAllDeviceProps {
                            properties.forEach { (property) in
                                // If the property is already present in received properties, just directly replace it!
                                if let existingIndex = lastProperties.firstIndex(where: { (existingProperty) -> Bool in
                                    return property.code == existingProperty.code
                                }) {
                                    lastProperties[existingIndex] = property
                                } else { // Otherwise append it to the array
                                    lastProperties.append(property)
                                }
                            }
                            properties = lastProperties
                        }

                        let eventAndStillModes = CameraEvent.fromSonyDeviceProperties(properties)
                        var event = eventAndStillModes.event
//                        print("""
//                                GOT EVENT:
//                                \(properties)
//                                """)
                        self.lastStillCaptureModes = eventAndStillModes.stillCaptureModes
                        event.postViewPictureURLs = self.imageURLs.compactMapValues({ (urls) -> [(postView: URL, thumbnail: URL?)]? in
                            return urls.map({ ($0, nil) })
                        })
                        event.bulbShootingURLS = self.imageURLs[.bulb].flatMap({ return [$0] })

                        self.imageURLs = [:]
                        callback(nil, event as? T.ReturnType)
                    case .failure(let error):
                        callback(error, nil)
                    }
                }, partial: lastAllDeviceProps != nil)*/
                                
                return
            }
            
            lastEvent.postViewPictureURLs = self.imageURLs.compactMapValues({ (urls) -> [(postView: URL, thumbnail: URL?)]? in
                return urls.map({ ($0, nil) })
            })
            lastEvent.bulbShootingURLS = self.imageURLs[.bulb].flatMap({ return [$0] })
            
            imageURLs = [:]
            callback(nil, lastEvent as? T.ReturnType)
            
        case .setShootMode:
            guard let value = payload as? ShootingMode else {
                callback(FunctionError.invalidPayload, nil)
                return
            }
            guard let stillCapMode = bestStillCaptureMode(for: value) else {
                guard let exposureProgrammeMode = self.bestExposureProgrammeModes(for: value, currentExposureProgrammeMode: self.lastEvent?.exposureMode?.current)?.first else {
                    callback(FunctionError.notAvailable, nil)
                    return
                }
                self.setExposureProgrammeMode(exposureProgrammeMode) { (programmeError) in
                    // We return error here, as if callers obey the available shoot modes they shouldn't be calling this with an invalid value
                    callback(programmeError, nil)
                }
                return
            }
            setStillCaptureMode(stillCapMode) { [weak self] (error) in
                guard let self = self, error == nil, let exposureProgrammeMode = self.bestExposureProgrammeModes(for: value, currentExposureProgrammeMode: self.lastEvent?.exposureMode?.current)?.first else {
                    callback(error, nil)
                    return
                }
                self.setExposureProgrammeMode(exposureProgrammeMode) { (programmeError) in
                    // We return error here, as if callers obey the available shoot modes they shouldn't be calling this with an invalid value
                    callback(programmeError, nil)
                }
            }
        case .getShootMode:
            getDevicePropDescriptionsFor(propCodes: [.stillCaptureMode, .exposureProgramMode]) { (result) in
             
                switch result {
                case .success(let properties):
                    let event = CameraEvent.fromSonyDeviceProperties(properties).event
                    callback(nil, event.shootMode?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .setContinuousShootingMode:
            // This isn't a thing via PTP according to Sony's app (Instead we just have multiple continuous shooting speeds) so we just don't do anything!
            callback(nil, nil)
        case .setISO, .setShutterSpeed, .setAperture, .setExposureCompensation, .setFocusMode, .setExposureMode, .setExposureModeDialControl, .setFlashMode, .setContinuousShootingSpeed, .setStillQuality, .setStillFormat, .setVideoFileFormat, .setVideoQuality, .setContinuousBracketedShootingBracket, .setSingleBracketedShootingBracket, .setLiveViewQuality:
            
            print("CANON SET \(function.function): \(payload)")
            guard let value = payload as? CanonPTPPropValueConvertable else {
                print("CANON INVALID PAYLOAD \(payload)")
                callback(FunctionError.invalidPayload, nil)
                return
            }
            
            ptpIPClient?.setDevicePropValueEx(
                PTP.DeviceProperty.Value(value),
                value.canonPTPCode,
                callback: { (response) in
                    callback(response.code.isError ? PTPError.commandRequestFailed(response.code) : nil, nil)
                }
            )
            /*ptpIPClient?.sendSetControlDeviceAValue(
                PTP.DeviceProperty.Value(value),
                callback: { (response) in
                    callback(response.code.isError ? PTPError.commandRequestFailed(response.code) : nil, nil)
                }
            )*/
        case .getISO:
            getDevicePropDescriptionFor(propCode: .ISO, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.iso?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getShutterSpeed:
            getDevicePropDescriptionFor(propCode: .shutterSpeed, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.shutterSpeed?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getAperture:
            getDevicePropDescriptionFor(propCode: .fNumber, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.aperture?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getExposureCompensation:
            getDevicePropDescriptionFor(propCode: .exposureBiasCompensation, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.aperture?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getFocusMode:
            getDevicePropDescriptionFor(propCode: .focusMode, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.focusMode?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getExposureMode:
            getDevicePropDescriptionFor(propCode: .exposureProgramMode, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.exposureMode?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getExposureModeDialControl:
            getDevicePropDescriptionFor(propCode: .exposureProgramModeControl, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.exposureMode?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getFlashMode:
            getDevicePropDescriptionFor(propCode: .flashMode, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.flashMode?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getSingleBracketedShootingBracket:
            getDevicePropDescriptionFor(propCode: .stillCaptureMode) { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.singleBracketedShootingBrackets?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .getContinuousBracketedShootingBracket:
            getDevicePropDescriptionFor(propCode: .stillCaptureMode) { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.continuousBracketedShootingBrackets?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .setStillSize:
            guard let stillSize = payload as? StillCapture.Size.Value else {
                callback(FunctionError.invalidPayload, nil)
                return
            }
            var stillSizeByte: Byte? = nil
            switch stillSize.size {
            case "L":
                stillSizeByte = 0x01
            case "M":
                stillSizeByte = 0x02
            case "S":
                stillSizeByte = 0x03
            default:
                break
            }
            
            if let _stillSizeByte = stillSizeByte {
                ptpIPClient?.sendSetControlDeviceAValue(
                    PTP.DeviceProperty.Value(
                        code: .imageSizeSony,
                        type: .uint8,
                        value: _stillSizeByte
                    )
                )
            }
            
            guard let aspect = stillSize.aspectRatio else { return }
            
            var aspectRatioByte: Byte? = nil
            switch aspect {
            case "3:2":
                aspectRatioByte = 0x01
            case "16:9":
                aspectRatioByte = 0x02
            case "1:1":
                aspectRatioByte = 0x04
            default:
                break
            }
            
            guard let _aspectRatioByte = aspectRatioByte else { return }
            
            ptpIPClient?.sendSetControlDeviceAValue(
                PTP.DeviceProperty.Value(
                    code: .imageSizeSony,
                    type: .uint8,
                    value: _aspectRatioByte
                )
            )
            
        case .getStillSize:
            
            // Still size requires still size and ratio codes to be fetched!
            // Still size requires still size and ratio codes to be fetched!
            getDevicePropDescriptionsFor(propCodes: [.imageSizeSony, .aspectRatio]) { (result) in
                switch result {
                case .success(let properties):
                    let event = CameraEvent.fromSonyDeviceProperties(properties).event
                    callback(nil, event.stillSizeInfo?.stillSize as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
            
        case .setSelfTimerDuration:
            guard let timeInterval = payload as? TimeInterval else {
                callback(FunctionError.invalidPayload, nil)
                return
            }
            let value: SonyStillCaptureMode
            switch timeInterval {
            case 0.0:
                value = .single
            case 2.0:
                value = .timer2
            case 5.0:
                value = .timer5
            case 10.0:
                value = .timer10
            default:
                value = .single
            }
            ptpIPClient?.sendSetControlDeviceAValue(
                PTP.DeviceProperty.Value(value)
            )
        case .getSelfTimerDuration:
            
            getDevicePropDescriptionFor(propCode: .stillCaptureMode, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.selfTimer?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
            
        case .setWhiteBalance:
            
            guard let value = payload as? WhiteBalance.Value else {
                callback(FunctionError.invalidPayload, nil)
                return
            }
            ptpIPClient?.sendSetControlDeviceAValue(
                PTP.DeviceProperty.Value(value.mode)
            )
            guard let colorTemp = value.temperature else { return }
            ptpIPClient?.sendSetControlDeviceAValue(
                PTP.DeviceProperty.Value(
                    code: .colorTemp,
                    type: .uint16,
                    value: Word(colorTemp)
                )
            )
            
        case .getWhiteBalance:
            
            // White balance requires white balance and colorTemp codes to be fetched!
            getDevicePropDescriptionsFor(propCodes: [.whiteBalance, .colorTemp]) { (result) in
                switch result {
                case .success(let properties):
                    let event = CameraEvent.fromSonyDeviceProperties(properties).event
                    callback(nil, event.whiteBalance?.whitebalanceValue as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .setupCustomWhiteBalanceFromShot:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setProgramShift, .getProgramShift:
            // Not available natively with PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .takePicture, .takeSingleBracketShot:
            takePicture { (result) in
                Logger.log(message: "Intervalometer - Taking picture RESULT \(result)", category: "SonyPTPIPCamera", level: .debug)
                os_log("Intervalometer - Taking picture RESULT", log: self.log, type: .debug)

                switch result {
                case .success(let url):
                    callback(nil, url as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .startContinuousShooting, .startContinuousBracketShooting:
            /*startCapturing { (error) in
                callback(error, nil)
            }
            callback(nil, nil)*/
            callback(nil, nil)
        case .endContinuousShooting, .stopContinuousBracketShooting:
            // Only await image if we're continuous shooting, continuous bracket behaves strangely
            // in that the user must manually trigger the completion and so `ObjectID` event will have been received
            // long ago!
            /*finishCapturing(awaitObjectId: function.function == .endContinuousShooting) { (result) in
                switch result {
                case .failure(let error):
                    callback(error, nil)
                case .success(let url):
                    callback(nil, url as? T.ReturnType)
                }
            }*/
            callback(nil, nil)
        case .startVideoRecording:
            self.ptpIPClient?.sendSetControlDeviceBValue(
                PTP.DeviceProperty.Value(
                    code: .movie,
                    type: .uint16,
                    value: Word(2)
                ),
                callback: { (videoResponse) in
                    guard !videoResponse.code.isError else {
                        callback(PTPError.commandRequestFailed(videoResponse.code), nil)
                        return
                    }
                    callback(nil, nil)
                }
            )
        case .recordHighFrameRateCapture:
            self.ptpIPClient?.sendSetControlDeviceBValue(
                PTP.DeviceProperty.Value(
                    code: .movie,
                    type: .uint16,
                    value: Word(2)
                ),
                callback: { [weak self] (videoResponse) in
                    guard !videoResponse.code.isError else {
                        callback(PTPError.commandRequestFailed(videoResponse.code), HighFrameRateCapture.Status.idle as? T.ReturnType)
                        return
                    }
                    callback(nil, HighFrameRateCapture.Status.buffering as? T.ReturnType)
                    guard let self = self else { return }
                    self.highFrameRateCallback = { [weak self] result in
                        switch result {
                        case .success(let status):
                            callback(nil, status as? T.ReturnType)
                            if status == .idle {
                                self?.highFrameRateCallback = nil
                            }
                        case .failure(let error):
                            callback(error, nil)
                            self?.highFrameRateCallback = nil
                        }
                    }
                }
            )
        case .endVideoRecording:
            self.ptpIPClient?.sendSetControlDeviceBValue(
                PTP.DeviceProperty.Value(
                    code: .movie,
                    type: .uint16,
                    value: Word(1)
                ),
                callback: { (videoResponse) in
                    guard !videoResponse.code.isError else {
                        callback(PTPError.commandRequestFailed(videoResponse.code), nil)
                        return
                    }
                    callback(nil, nil)
                }
            )
        case .startAudioRecording, .endAudioRecording:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .startIntervalStillRecording, .endIntervalStillRecording:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .startLoopRecording, .endLoopRecording:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .startBulbCapture:
            /*startCapturing { [weak self] (error) in
                
                guard error == nil else {
                    callback(error, nil)
                    return
                }
                
                self?.awaitFocusIfNeeded { () in
                    callback(nil, nil)
                }
            }*/
            callback(nil, nil)
        case .endBulbCapture:
            /*finishCapturing() { (result) in
                switch result {
                case .failure(let error):
                    callback(error, nil)
                case .success(let url):
                    callback(nil, url as? T.ReturnType)
                }
            }*/
            callback(nil, nil)
        case .startLiveView, .startLiveViewWithQuality, .endLiveView:
            getDevicePropDescriptionFor(propCode: .liveViewURL) { [weak self] (result) in
                
                guard let self = self else { return }
                switch result {
                case .success(let property):
                    
                    var url: URL? = nil // = self.apiDeviceInfo.liveViewURL
                    if let string = property.currentValue as? String, let returnedURL = URL(string: string) {
                        url = returnedURL
                    }
                    
                    guard function.function == .startLiveViewWithQuality, let quality = payload as? LiveView.Quality else {
                        callback(nil, url as? T.ReturnType)
                        return
                    }
                    
                    self.performFunction(
                        LiveView.QualitySet.set,
                        payload: quality) { (_, _) in
                        callback(nil, url as? T.ReturnType)
                    }
                    
                case .failure(_):
                    callback(nil, nil)
                }
            }
        case .getLiveViewQuality:
            getDevicePropDescriptionFor(propCode: .liveViewQuality, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.liveViewQuality?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .setSendLiveViewFrameInfo:
            // Doesn't seem to be available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .getSendLiveViewFrameInfo:
            // Doesn't seem to be available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .startZooming:
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .stopZooming:
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .setZoomSetting, .getZoomSetting:
            // Doesn't seem to be available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .halfPressShutter, .cancelHalfPressShutter:
            ptpIPClient?.sendSetControlDeviceBValue(
                PTP.DeviceProperty.Value(
                    code: .autoFocus,
                    type: .uint16,
                    value: function.function == .halfPressShutter ? Word(2) : Word(1)
                ), callback: { response in
                    callback(response.code.isError ? PTPError.commandRequestFailed(response.code) : nil, nil)
                }
            )
        case .setTouchAFPosition, .getTouchAFPosition, .cancelTouchAFPosition, .startTrackingFocus, .stopTrackingFocus, .setTrackingFocus, .getTrackingFocus:
            // Doesn't seem to be available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .getContinuousShootingMode:
            getDevicePropDescriptionFor(propCode: .stillCaptureMode, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.continuousShootingMode?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
            callback(nil, nil)
        case .getContinuousShootingSpeed:
            getDevicePropDescriptionFor(propCode: .stillCaptureMode, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.continuousShootingSpeed?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getStillQuality:
            getDevicePropDescriptionFor(propCode: .stillQuality, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.stillQuality?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getPostviewImageSize:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setPostviewImageSize:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .getVideoFileFormat:
            getDevicePropDescriptionFor(propCode: .movieFormat, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.videoFileFormat?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getVideoQuality:
            getDevicePropDescriptionFor(propCode: .movieQuality, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.videoQuality?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .setSteadyMode:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .getSteadyMode:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setViewAngle:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .getViewAngle:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setScene:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .getScene:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setColorSetting:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .getColorSetting:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setIntervalTime, .getIntervalTime:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setLoopRecordDuration, .getLoopRecordDuration:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setWindNoiseReduction:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .getWindNoiseReduction:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setAudioRecording:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .getAudioRecording:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setFlipSetting, .getFlipSetting:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setTVColorSystem, .getTVColorSystem:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .listContent, .getContentCount, .listSchemes, .listSources, .deleteContent, .setStreamingContent, .startStreaming, .pauseStreaming, .seekStreamingPosition, .stopStreaming, .getStreamingStatus:
            // Not available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .getInfraredRemoteControl, .setInfraredRemoteControl:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setAutoPowerOff, .getAutoPowerOff:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setBeepMode, .getBeepMode:
            //TODO: Unable to reverse engineer as not supported on RX100 VII
            callback(nil, nil)
        case .setCurrentTime:
            //TODO: Implement
            callback(nil, nil)
        case .getStorageInformation:
            // Requires either remaining shots or remaining capture time to function
            getDevicePropDescriptionsFor(propCodes: [.remainingShots, .remainingCaptureTime, .storageState]) { (result) in
                switch result {
                case .success(let properties):
                    let event = CameraEvent.fromSonyDeviceProperties(properties).event
                    callback(nil, event.storageInformation as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .setCameraFunction:
            callback(CameraError.noSuchMethod("setCameraFunction"), nil)
        case .getCameraFunction:
            callback(CameraError.noSuchMethod("getCameraFunction"), nil)
        case .ping:
            ptpIPClient?.ping(callback: { (error) in
                callback(nil, nil)
            })
        case .startRecordMode:
            callback(CameraError.noSuchMethod("startRecordMode"), nil)
        case .getStillFormat:
            getDevicePropDescriptionFor(propCode: .stillFormat, callback: { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.stillFormat?.current as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            })
        case .getExposureSettingsLock:
            getDevicePropDescriptionFor(propCode: .exposureSettingsLockStatus) { (result) in
                switch result {
                case .success(let property):
                    let event = CameraEvent.fromSonyDeviceProperties([property]).event
                    callback(nil, event.exposureSettingsLockStatus as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .setExposureSettingsLock:

            // This may seem strange, that to move to standby we set this value twice, but this is what works!
            // It doesn't seem like we actually need the value at all, it just toggles it on this camera...
            ptpIPClient?.sendSetControlDeviceBValue(
                PTP.DeviceProperty.Value(
                    code: .exposureSettingsLock,
                    type: .uint16,
                    value: Word(0x01)
                ),
                callback: { [weak self] (response) in
                    guard let self = self else { return }
                    guard !response.code.isError else {
                        callback(response.code.isError ? PTPError.commandRequestFailed(response.code) : nil, nil)
                        return
                    }
                    self.ptpIPClient?.sendSetControlDeviceBValue(
                        PTP.DeviceProperty.Value(
                            code: .exposureSettingsLock,
                            type: .uint16,
                            value: Word(0x02)
                        ),
                        callback: { (innerResponse) in
                            callback(innerResponse.code.isError ? PTPError.commandRequestFailed(innerResponse.code) : nil, nil)
                        }
                    )
                }
            )
        }
    }
}
