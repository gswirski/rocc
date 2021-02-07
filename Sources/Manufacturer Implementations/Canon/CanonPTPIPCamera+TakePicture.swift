//
//  SonyPTPIPCamera+TakePicture.swift
//  Rocc
//
//  Created by Simon Mitchell on 22/01/2020.
//  Copyright © 2020 Simon Mitchell. All rights reserved.
//

import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension CanonPTPIPDevice {
    enum CaptureError: Error {
        case noObjectId
    }

    typealias CaptureCompletion = (Result<URL?, Error>) -> Void
    
    func takePicture(completion: @escaping CaptureCompletion) {
        
        Logger.log(message: "Intervalometer - Taking picture...", category: "CanonPTPIPCamera", level: .debug)
        os_log("Intervalometer - Taking picture...", log: log, type: .debug)
        
        ptpIPClient?.sendRemoteReleaseOn(callback: { [weak self] (_) in
            guard let self = self else { return }
            
            self.awaitFocus { [weak self] () in
                self?.ptpIPClient?.sendRemoteReleaseOff(callback: { (_) in
                    guard let self = self else { return }

                    self.awaitObject { [weak self] (_ objectId: DWord?) in
                        guard let self = self else { return }
                        
                        guard let objectId = objectId else {
                            completion(.failure(CaptureError.noObjectId))
                            return
                        }
                        
                        self.ptpIPClient?.getReducedObject(objectId: objectId) { (data) in
                            switch data {
                            case .success(let container):
                                let data = Data(container.data)
                                guard let image = UIImage(data: data) else {
                                    completion(.success(nil))
                                    return
                                }
                                
                                let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                                let fileName = "\(ProcessInfo().globallyUniqueString).jpg"
                                let imageURL = temporaryDirectoryURL.appendingPathComponent(fileName)
                                do {
                                    try data.write(to: imageURL)
                                    completion(.success(imageURL))
                                } catch let error {
                                    Logger.log(message: "Failed to save image to disk: \(error.localizedDescription)", category: "SonyPTPIPCamera", level: .error)
                                    os_log("Failed to save image to disk", log: self.log, type: .error)
                                    completion(.success(nil))
                                }
                                print("Received Thumbnail data \(image)") //" \(container.data.toHex)")
                            case .failure(let error):
                                print("Received Thumbnail error \(error)")
                            }
                            
                            completion(.success(nil))
                        }
                    }
                })
            }
        })
    }
    
    func awaitObject(completion: @escaping (_ objectID: DWord?) -> Void) {
        Logger.log(message: "Awaiting object after capture", category: "SonyPTPIPCamera", level: .debug)
        os_log("Awaiting object after capture", log: self.log, type: .debug)
        
        var objectID: DWord? = nil
        DispatchQueue.global().asyncWhile({ [weak self] (continueClosure) in
            
            guard let self = self else { return }
            
            print("Last Object Added: \(self.lastObjectAdded)")
            if let lastObjectAdded = self.lastObjectAdded, let id = lastObjectAdded[dWord: 8] {
                objectID = id
                /*let storageID = lastObjectAdded[dWord: 12]!
                let OFC = lastObjectAdded[dWord: 16]!
                let size = lastObjectAdded[dWord: 28]!
                let parent = lastObjectAdded[dWord: 36]!*/

                self.lastObjectAdded = nil
                continueClosure(true)
                return
            }
            
            continueClosure(false)
        }, timeout: 10) {
            completion(objectID)
        }
    }
    
    func awaitFocus(completion: @escaping () -> Void) {
        
        Logger.log(message: "Focus mode is AF variant awaiting focus...", category: "SonyPTPIPCamera", level: .debug)
        os_log("Focus mode is AF variant awaiting focus...", log: self.log, type: .debug)
        
        DispatchQueue.global().asyncWhile({ [weak self] (continueClosure) in
            
            guard let self = self else { return }
            
            if let lastOLCChange = self.lastOLCInfoChanged {
                let len = lastOLCChange[dWord: 0]
                let mask = lastOLCChange[word: 4]!
                let val = lastOLCChange[word: 8]!

                if (mask & 0x0001) != 0 {
                    print("Intervalometer - property size: \(len) BUTTON(\(mask)) - \(val)")
                    
                    // 4 is success, 3 is fail, 1 is "normal" after the entire focusing sequence finished
                    if val != 2 && val != 7 {
                        continueClosure(true)
                    }
                }
            }
            
            continueClosure(false)
        }, timeout: 1) { [weak self] in
            
            guard let self = self else { return }
            
            completion()
        }
    }
    
    func awaitFocusIfNeeded(completion: @escaping () -> Void) {
        
        guard let focusMode = self.lastEvent?.focusMode?.current else {
            
            self.performFunction(Focus.Mode.get, payload: nil) { [weak self] (_, focusMode) in
            
                guard let self = self else {
                    return
                }
                
                guard focusMode?.isAutoFocus == true else {
                    completion()
                    return
                }
                
                self.awaitFocus(completion: completion)
            }
            
            return
        }
        
        guard focusMode.isAutoFocus else {
            completion()
            return
        }
        
        self.awaitFocus(completion: completion)
    }
 
    func startCapturing(completion: @escaping (Error?) -> Void) {
        
        Logger.log(message: "Starting capture...", category: "SonyPTPIPCamera", level: .debug)
        os_log("Starting capture...", log: self.log, type: .debug)
        
        ptpIPClient?.sendSetControlDeviceBValue(
            PTP.DeviceProperty.Value(
                code: .autoFocus,
                type: .uint16,
                value: Word(2)
            ),
            callback: { [weak self] (_) in
                
                guard let self = self else { return }
                
                Logger.log(message: "Intervalometer - Starting capture completion A", category: "SonyPTPIPCamera", level: .debug)
                os_log("Intervalometer - Starting capture completion A", log: self.log, type: .debug)
                
                self.ptpIPClient?.sendSetControlDeviceBValue(
                    PTP.DeviceProperty.Value(
                        code: .capture,
                        type: .uint16,
                        value: Word(2)
                    ),
                    callback: { (shutterResponse) in
                        Logger.log(message: "Intervalometer - Starting capture completion B \(shutterResponse)", category: "SonyPTPIPCamera", level: .debug)
                        os_log("Intervalometer - Starting capture completion B", log: self.log, type: .debug)

                        guard !shutterResponse.code.isError else {
                            completion(PTPError.commandRequestFailed(shutterResponse.code))
                            return
                        }
                        completion(nil)
                    }
                )
            }
        )
    }
    
    func finishCapturing(awaitObjectId: Bool = true, completion: @escaping CaptureCompletion) {
        
        cancelShutterPress(objectID: nil, awaitObjectId: awaitObjectId, completion: completion)
    }
    
    private func cancelShutterPress(objectID: DWord?, awaitObjectId: Bool = true, completion: @escaping CaptureCompletion) {
        
        Logger.log(message: "Intervalometer - Cancelling shutter press \(objectID != nil ? "\(objectID!)" : "null")", category: "SonyPTPIPCamera", level: .debug)
        os_log("Intervalometer - Cancelling shutter press %@", log: self.log, type: .debug, objectID != nil ? "\(objectID!)" : "null")
                
        ptpIPClient?.sendSetControlDeviceBValue(
            PTP.DeviceProperty.Value(
                code: .capture,
                type: .uint16,
                value: Word(1)
            ),
            callback: { [weak self] response in
                
                guard let self = self else { return }
                
                Logger.log(message: "Intervalometer - Shutter press set to 1", category: "SonyPTPIPCamera", level: .debug)
                os_log("Intervalometer - Shutter press set to 1", log: self.log, type: .debug, objectID != nil ? "\(objectID!)" : "null")
                
                self.ptpIPClient?.sendSetControlDeviceBValue(
                    PTP.DeviceProperty.Value(
                        code: .autoFocus,
                        type: .uint16,
                        value: Word(1)
                    ),
                    callback: { [weak self] (_) in
                        guard let self = self else { return }
                        
                        Logger.log(message: "Intervalometer - Autofocus set to 1 \(String(describing: objectID))", category: "SonyPTPIPCamera", level: .debug)
                        os_log("Intervalometer - Autofocus set to 1", log: self.log, type: .debug, objectID != nil ? "\(objectID!)"
                            : "null")
                        guard objectID != nil || !awaitObjectId else {
                            Logger.log(message: "Intervalometer - awaiting object id \(String(describing: objectID)) with \(awaitObjectId)", category: "SonyPTPIPCamera", level: .debug)
                            os_log("Intervalometer - awaiting object id", log: self.log, type: .debug, objectID != nil ? "\(objectID!)"
                                : "null")

                            self.awaitObjectId(completion: completion)
                            return
                        }
                        completion(Result.success(nil))
                    }
                )
            }
        )
    }
    
    private func awaitObjectId(completion: @escaping CaptureCompletion) {
        
        var newObject: DWord?
        
        Logger.log(message: "Awaiting Object ID", category: "SonyPTPIPCamera", level: .debug)
        os_log("Awaiting Object ID", log: self.log, type: .debug)
        
        // If we already have an awaitingObjectId! For some reason this isn't caught if we jump into asyncWhile...
        guard awaitingObjectId == nil else {
            
            awaitingObjectId = nil
            isAwaitingObject = false
            // If we've got an object ID successfully then we captured an image, and we can callback, it's not necessary to transfer image to carry on.
            // We will transfer the image when the event is received...
            completion(Result.success(nil))
            
            return
        }
        
        DispatchQueue.global().asyncWhile({ [weak self] (continueClosure) in
            
            guard let self = self else { return }
            
            if let lastEvent = self.lastEventPacket, lastEvent.code == .objectAdded {
                
                Logger.log(message: "Got property changed event and was \"Object Added\", continuing with capture process", category: "SonyPTPIPCamera", level: .debug)
                os_log("Got property changed event and was \"Object Added\", continuing with capture process", log: self.log, type: .debug)
                self.isAwaitingObject = false
                newObject = lastEvent.variables?.first ?? self.awaitingObjectId
                self.awaitingObjectId = nil
                continueClosure(true)
                return
                
            } else if let awaitingObjectId = self.awaitingObjectId {
                
                Logger.log(message: "\"Object Added\" event was intercepted elsewhere, continuing with capture process", category: "SonyPTPIPCamera", level: .debug)
                os_log("\"Object Added\" event was intercepted elsewhere, continuing with capture process", log: self.log, type: .debug)
                
                self.isAwaitingObject = false
                newObject = awaitingObjectId
                self.awaitingObjectId = nil
                continueClosure(true)
                return
            }
            
            Logger.log(message: "Getting device prop description for 'objectInMemory'", category: "SonyPTPIPCamera", level: .debug)
            os_log("Getting device prop description for 'objectInMemory'", log: self.log, type: .debug)
            
            self.getDevicePropDescriptionFor(propCode: .objectInMemory, callback: { (result) in
                
                Logger.log(message: "Intervalometer - Got device prop description for 'objectInMemory': \(result)", category: "SonyPTPIPCamera", level: .debug)
                os_log("Got device prop description for 'objectInMemory'", log: self.log, type: .debug)
                
                switch result {
                case .failure(_):
                    continueClosure(false)
                case .success(let property):
                    // if prop 0xd215 > 0x8000, the object in RAM is available at location 0xffffc001
                    // This variable also turns to 1 , but downloading then will crash the firmware
                    // we seem to need to wait for 0x8000 (See https://github.com/gphoto/libgphoto2/blob/de98b151bce6b0aa70157d6c0ebb7f59b4da3792/camlibs/ptp2/library.c#L4330)
                    guard let value = property.currentValue.toInt, value >= 0x8000 else {
                        Logger.log(message: "Intervalometer - Got device prop description for 'objectInMemory' value \(property.currentValue.toInt)", category: "SonyPTPIPCamera", level: .debug)
                        os_log("Intervalometer - Got device prop description for 'objectInMemory' wrong value", log: self.log, type: .debug)

                        
                        continueClosure(false)
                        return
                    }
                    
                    Logger.log(message: "objectInMemory >= 0x8000, object in memory at 0xffffc001", category: "SonyPTPIPCamera", level: .debug)
                    os_log("objectInMemory >= 0x8000, object in memory at 0xffffc001", log: self.log, type: .debug)
                    
                    self.isAwaitingObject = false
                    self.awaitingObjectId = nil
                    newObject = 0xffffc001
                    continueClosure(true)
                }
            })

        }, timeout: 35) { [weak self] in
            
            self?.awaitingObjectId = nil
            self?.isAwaitingObject = false

            guard newObject != nil else {
                completion(Result.failure(PTPError.objectNotFound))
                return
            }
            
            // If we've got an object ID successfully then we captured an image, and we can callback, it's not necessary to transfer image to carry on.
            // We will transfer the image when the event is received...
            completion(Result.success(nil))
        }
    }
    
    func handleObjectId(objectID: DWord, shootingMode: ShootingMode, completion: @escaping CaptureCompletion) {
        
        Logger.log(message: "Got object with id: \(objectID)", category: "SonyPTPIPCamera", level: .debug)
        os_log("Got object ID", log: log, type: .debug)
        
        ptpIPClient?.getObjectInfoFor(objectId: objectID, callback: { [weak self] (result) in
            
            guard let self = self else { return }
            
            switch result {
            case .success(let info):
                // Call completion as technically now ready to take an image!
                completion(Result.success(nil))
                self.getObjectWith(info: info, objectID: objectID, shootingMode: shootingMode, completion: completion)
            case .failure(_):
                // Doesn't really matter if this part fails, as image already taken
                completion(Result.success(nil))
            }
        })
    }
    
    private func getObjectWith(info: PTP.ObjectInfo, objectID: DWord, shootingMode: ShootingMode, completion: @escaping CaptureCompletion) {
        
        Logger.log(message: "Getting object of size: \(info.compressedSize) with id: \(objectID)", category: "SonyPTPIPCamera", level: .debug)
        os_log("Getting object", log: log, type: .debug)
        
        let packet = Packet.commandRequestPacket(code: .getPartialObject, arguments: [objectID, 0, info.compressedSize], transactionId: ptpIPClient?.getNextTransactionId() ?? 2)
        ptpIPClient?.awaitDataFor(transactionId: packet.transactionId, callback: { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                self.handleObjectData(data.data, shootingMode: shootingMode, fileName: info.fileName ?? "\(ProcessInfo().globallyUniqueString).jpg")
            case .failure(let error):
                Logger.log(message: "Failed to get object: \(error.localizedDescription)", category: "SonyPTPIPCamera", level: .error)
                os_log("Failed to get object", log: self.log, type: .error)
                break
            }
        })
        ptpIPClient?.sendCommandRequestPacket(packet, callback: nil)
    }
    
    private func handleObjectData(_ data: ByteBuffer, shootingMode: ShootingMode, fileName: String) {
        
        Logger.log(message: "Got object data!: \(data.length). Attempting to save as image", category: "SonyPTPIPCamera", level: .debug)
        os_log("Got object data! Attempting to save as image", log: self.log, type: .debug)
        
        // Check for a new object, in-case we missed the event for it!
        getDevicePropDescriptionFor(propCode: .objectInMemory, callback: { [weak self] (result) in
            
            guard let self = self else { return }
            
            switch result {
            case .failure(_):
                break
            case .success(let property):
                // if prop 0xd215 > 0x8000, the object in RAM is available at location 0xffffc001
                // This variable also turns to 1 , but downloading then will crash the firmware
                // we seem to need to wait for 0x8000 (See https://github.com/gphoto/libgphoto2/blob/de98b151bce6b0aa70157d6c0ebb7f59b4da3792/camlibs/ptp2/library.c#L4330)
                guard let value = property.currentValue.toInt, value >= 0x8000 else {
                    return
                }
                self.handleObjectId(objectID: 0xffffc001, shootingMode: shootingMode) { (_) in
                    
                }
            }
        })
        
        let imageData = Data(data)
        guard Image(data: imageData) != nil else {
            Logger.log(message: "Image data not valid", category: "SonyPTPIPCamera", level: .error)
            os_log("Image data not valud", log: self.log, type: .error)
            return
        }
        
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let imageURL = temporaryDirectoryURL.appendingPathComponent(fileName)
        do {
            try imageData.write(to: imageURL)
            imageURLs[shootingMode, default: []].append(imageURL)
            // Trigger dummy event
            onEventAvailable?()
        } catch let error {
            Logger.log(message: "Failed to save image to disk: \(error.localizedDescription)", category: "SonyPTPIPCamera", level: .error)
            os_log("Failed to save image to disk", log: self.log, type: .error)
        }
    }
}
