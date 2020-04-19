//
//  SonyPTPIPCamera+PerformFunction.swift
//  Rocc
//
//  Created by Simon Mitchell on 17/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation
import os.log

extension SonyPTPIPDevice {
    
    func performFunction<T>(_ function: T, payload: T.SendType?, callback: @escaping ((Error?, T.ReturnType?) -> Void)) where T : CameraFunction {
        
        switch function.function {
        case .getEvent:
            
            guard !imageURLs.isEmpty, var lastEvent = lastEvent else {
                
                ptpIPClient?.getAllDevicePropDesc(callback: { [weak self] (result) in
                    guard let self = self else { return }
                    switch result {
                    case .success(let properties):
                        let eventAndStillModes = CameraEvent.fromSonyDeviceProperties(properties)
                        var event = eventAndStillModes.event
//                        print("""
//                                GOT EVENT:
//                                \(properties)
//                                """)
                        self.lastStillCaptureModes = eventAndStillModes.stillCaptureModes
                        event.postViewPictureURLs = self.imageURLs[.photo].flatMap({ return [$0] })
                        event.continuousShootingURLS = self.imageURLs[.continuous]?.compactMap({ (url) -> (postView: URL, thumbnail: URL) in
                            return (postView: url, thumbnail: url)
                        })
                        self.imageURLs = [:]
                        callback(nil, event as? T.ReturnType)
                    case .failure(let error):
                        callback(error, nil)
                    }
                })
                
                return
            }
            
            lastEvent.postViewPictureURLs = self.imageURLs[.photo].flatMap({ return [$0] })
            lastEvent.continuousShootingURLS = self.imageURLs[.continuous]?.compactMap({ (url) -> (postView: URL, thumbnail: URL) in
                return (postView: url, thumbnail: url)
            })
            
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
        case .setISO, .setShutterSpeed, .setAperture, .setExposureCompensation, .setFocusMode, .setExposureMode, .setExposureModeDialControl, .setFlashMode, .setContinuousShootingSpeed, .setStillQuality, .setStillFormat, .setVideoFileFormat, .setVideoQuality:
            guard let value = payload as? SonyPTPPropValueConvertable else {
                callback(FunctionError.invalidPayload, nil)
                return
            }
            ptpIPClient?.sendSetControlDeviceAValue(
                PTP.DeviceProperty.Value(value),
                callback: { (response) in
                    callback(response.code.isError ? PTPError.commandRequestFailed(response.code) : nil, nil)
                }
            )
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
                // Pick out whichever 10 second timer duration is available
                value = lastStillCaptureModes?.available.first(where: { (stillCapMode) -> Bool in
                    return stillCapMode.isSingleTimerMode && stillCapMode.timerDuration == 10.0
                }) ?? .timer10_a
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
        case .takePicture:
            takePicture { (result) in
                switch result {
                case .success(let url):
                    callback(nil, url as? T.ReturnType)
                case .failure(let error):
                    callback(error, nil)
                }
            }
        case .startContinuousShooting:
            startCapturing { (error) in
                callback(error, nil)
            }
            callback(nil, nil)
        case .endContinuousShooting:
            finishCapturing() { (result) in
                switch result {
                case .failure(let error):
                    callback(error, nil)
                case .success(let url):
                    callback(nil, url as? T.ReturnType)
                }
            }
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
            startCapturing { [weak self] (error) in
                
                guard error == nil else {
                    callback(error, nil)
                    return
                }
                
                self?.awaitFocusIfNeeded { (_) in
                    callback(nil, nil)
                }
            }
        case .endBulbCapture:
            finishCapturing() { (result) in
                switch result {
                case .failure(let error):
                    callback(error, nil)
                case .success(let url):
                    callback(nil, url as? T.ReturnType)
                }
            }
        case .startLiveView, .startLiveViewWithSize, .endLiveView:
            getDevicePropDescriptionFor(propCode: .liveViewURL) { [weak self] (result) in
                guard let self = self else { return }
                switch result {
                case .success(let property):
                    guard let string = property.currentValue as? String, let url = URL(string: string) else {
                        callback(nil, self.apiDeviceInfo.liveViewURL as? T.ReturnType)
                        return
                    }
                    callback(nil, url as? T.ReturnType)
                    
                    // After the callback set the live view quality
                    self.ptpIPClient?.sendSetControlDeviceAValue(
                        PTP.DeviceProperty.Value(
                            code: .liveViewQuality,
                            type: .uint8,
                            value: Byte(0x01)
                        )
                    )
                    
                case .failure(_):
                    callback(nil, self.apiDeviceInfo.liveViewURL as? T.ReturnType)
                }
            }
        case .getLiveViewSize:
            // Doesn't seem to be available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .setSendLiveViewFrameInfo:
            // Doesn't seem to be available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .getSendLiveViewFrameInfo:
            // Doesn't seem to be available via PTP/IP
            callback(FunctionError.notSupportedByAvailableVersion, nil)
        case .startZooming:
            guard let direction = payload as? Zoom.Direction else {
                callback(FunctionError.invalidPayload, nil)
                return
            }
            startZooming(direction: direction) { (error) in
                callback(error, nil)
            }
        case .stopZooming:
            stopZooming { (error) in
                callback(error, nil)
            }
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