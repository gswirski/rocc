//
//  CommandRequestPacket.swift
//  Rocc
//
//  Created by Simon Mitchell on 03/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation

struct CommandRequestPacket: Packetable {
    
    var name: Packet.Name
    
    var length: DWord
                
    var data: ByteBuffer = ByteBuffer()
    
    var transactionId: DWord
    
    init?(length: DWord, name: Packet.Name, data: ByteBuffer) {
        
        self.name = name
        self.length = length
        self.data = data
        self.transactionId = 0
    }
    
    init(transactionId: DWord) {
        self.transactionId = transactionId
        self.name = .cmdRequest
        self.length = 0
    }
    
    var commandCode: PTP.CommandCode? {
        guard let commandCodeWord = data[word: 12] else { return nil }
        return PTP.CommandCode(rawValue: commandCodeWord)
    }
    
    var debugDescription: String {
        return description
    }
    
    var description: String {
        let transactionId = data[dWord: UInt(Packet.headerLength + MemoryLayout<DWord>.size + MemoryLayout<Word>.size) ] ?? 0
        let code = commandCode != nil ? "\(commandCode!)" : "null"
        let contents = data.sliced(Packet.headerLength + (MemoryLayout<DWord>.size * 2) + MemoryLayout<Word>.size).toHex
        return "\(data.length) | n:\(name) | t:\(transactionId) | c:\(code) | \(contents)"
    }
}
