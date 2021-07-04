//
//  DataStartPacket.swift
//  Rocc
//
//  Created by Simon Mitchell on 03/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation

struct StartDataPacket: Packetable {
    
    var name: Packet.Name
    
    var length: DWord
    
    var data: ByteBuffer
    
    let transactionId: DWord
    
    let dataLength: QWord
    
    init?(length: DWord, name: Packet.Name, data: ByteBuffer) {
        
        self.length = length
        self.name = name
        
        var offset: UInt = 0
        
        guard let transactionId: DWord = data.read(offset: &offset) else { return nil }
        self.transactionId = transactionId
        
        guard let dataLength: QWord = data.read(offset: &offset) else { return nil }
        self.dataLength = dataLength
        
        self.data = data.sliced(Int(offset), Int(length) - Packet.headerLength)
    }
    
    init(transactionId: DWord, dataLength: QWord) {
        self.transactionId = transactionId
        name = .startDataPacket
        length = 20
        data = ByteBuffer()
        self.dataLength = dataLength
    }
    
    var debugDescription: String {
        return description
    }
    
    var description: String {
        return "\(length) | n:\(name) | t:\(transactionId) | dl:\(dataLength) | \(data.toHex)"
    }
}
