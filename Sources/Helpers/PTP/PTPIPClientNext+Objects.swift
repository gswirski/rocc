//
//  PTPIPClient+Objects.swift
//  Rocc
//
//  Created by Simon Mitchell on 22/01/2020.
//  Copyright © 2020 Simon Mitchell. All rights reserved.
//

import Foundation

extension PTPIPClientNext {
    
    typealias ObjectInfoCompletion = (_ result: Result<PTP.ObjectInfo, Error>) -> Void
    
    func getObjectInfoFor(objectId: DWord, callback: @escaping ObjectInfoCompletion) {
        
        let packet = CommandRequestPacketArguments(commandCode: .getObjectInfo, arguments: [objectId])
        sendCommandRequestPacket(packet, responseCallback: nil) { (dataResult) in
            switch dataResult {
            case .success(let data):
                guard let objectInfo = PTP.ObjectInfo(data: data.data) else {
                    callback(Result.failure(PTPIPClientError.invalidResponse))
                    return
                }
                callback(Result.success(objectInfo))
            case .failure(let error):
                callback(Result.failure(error))
            }
        }
    }
}
