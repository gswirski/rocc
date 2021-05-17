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

    typealias CaptureResponse = (Error?) -> Void
    typealias CaptureCompletion = (Result<URL?, Error>) -> Void
    
    func startTakingPicture(completion: @escaping CaptureResponse) {
        Logger.log(message: "Intervalometer - Taking picture...", category: "CanonPTPIPCamera", level: .debug)
        os_log("Intervalometer - Taking picture...", log: log, type: .debug)
        
        ptpIPClient?.sendRemoteReleaseOn(callback: { [weak self] (_) in
            guard let self = self else { return }
            
            self.awaitFocus { [weak self] () in
                completion(nil)
            }
        })
    }
    
    func stopTakingPicture(completion: @escaping CaptureCompletion) {
        ptpIPClient?.sendRemoteReleaseOff(callback: { [weak self] (_) in
            guard let self = self else { return }

            self.awaitObject { [weak self] (_ objectId: DWord?) in
                guard let self = self else { return }
                
                print("BULB capture objectId \(objectId)")
                guard let objectId = objectId else {
                    completion(.failure(CaptureError.noObjectId))
                    return
                }
                
                self.ptpIPClient?.getReducedObject(objectId: objectId) { (data) in
                    switch data {
                    case .success(let container):
                        let data = Data(container.data)
                        guard let image = UIImage(data: data) else {
                            Logger.log(message: "Could not decode image \(container.data.toHex)", category: "CanonPTPIPCamera")
                            os_log("Could not decode image", log: self.log, type: .error)
                            completion(.success(nil))
                            return
                        }
                        print("Received Thumbnail data \(image)")
                        
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
                         //" \(container.data.toHex)")
                    case .failure(let error):
                        Logger.log(message: "Received thumbnail error \(error)", category: "CanonPTPIPCamera")
                        completion(.failure(error))
                    }
                }
            }
        })
    }
    
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
                                completion(.failure(error))
                            }
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
        }, timeout: 3) {
            completion(objectID)
        }
    }
    
    func awaitFocus(completion: @escaping () -> Void) {
        
        Logger.log(message: "Intervalometer - Focus mode is AF variant awaiting focus...", category: "SonyPTPIPCamera", level: .debug)
        os_log("Intervalometer - Focus mode is AF variant awaiting focus...", log: self.log, type: .debug)
        
        var result: Word?
        
        var prevMask: Word?
        var prevVal: Word?
        
        DispatchQueue.global().asyncWhile({ [weak self] (continueClosure) in
            
            guard let self = self else { return }
            
            let lastOLCChange = self.lastOLCInfoChanged

            if lastOLCChange.button == 3 || lastOLCChange.button == 4 {
                result = lastOLCChange.button.map { UInt16($0) }
                return continueClosure(true)
            } else if let focusInfo = lastOLCChange.focusInfo, (focusInfo[word: 5] ?? 0) > 0 {
                result = (focusInfo[word: 5] ?? 0)
                return continueClosure(true)
            }
            
            continueClosure(false)
        }, timeout: 10) { [weak self] in
            
            guard let self = self else { return }
            
            Logger.log(message: "Intervalometer - focus completion \(result)", category: "PTPIPClient", level: .debug)
            
            completion()
        }
    }
}
