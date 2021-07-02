//
//  EndDataPacket.swift
//  Rocc
//
//  Created by Simon Mitchell on 03/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation

struct EndDataPacket: Packetable {
    
    var name: Packet.Name
    
    var length: DWord
    
    var data: ByteBuffer
    
    let transactionId: DWord
        
    init?(length: DWord, name: Packet.Name, data: ByteBuffer) {
        
        self.length = length
        self.name = name
        
        // If we don't have enough data yet, return nil, otherwise we'll get broken packets when parsing!
        guard data.length >= length - 8 else {
            return nil
        }
                
        guard let transactionId = data[dWord: 0] else { return nil }
        self.transactionId = transactionId
        
        // Use `length` here as otherwise we may end up stealing data from other packets!
        self.data = data.sliced(MemoryLayout<DWord>.size, Int(length) - Packet.headerLength)

        /*self.data = data
        
        guard let transactionId = data[dWord: 0] else { return nil }
        self.transactionId = transactionId*/
    }
    
    init(transactionId: DWord) {
        self.transactionId = transactionId
        name = .endDataPacket
        length = 12
        data = ByteBuffer()
    }
    
    var debugDescription: String {
        return description
    }
    
    var description: String {
        return "\(length) | n:\(name) | t:\(transactionId) | \(data.toHex)"

   }
}
