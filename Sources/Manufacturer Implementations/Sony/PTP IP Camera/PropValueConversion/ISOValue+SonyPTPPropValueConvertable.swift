//
//  ISOValue+SonyPTPPropValueConvertible.swift
//  Rocc
//
//  Created by Simon Mitchell on 08/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation

extension ISO.Value: SonyPTPPropValueConvertable {
    
    var type: PTP.DeviceProperty.DataType {
        return .uint32
    }
    
    var code: PTP.DeviceProperty.Code {
        return .ISO
    }
    
    init?(sonyValue: PTPDevicePropertyDataType) {
        
        guard let binaryInt = sonyValue.toInt else {
            return nil
        }
        
        switch binaryInt {
        case 0x00ffffff:
            self = .auto(nil)
        case 0x01ffffff:
            self = .multiFrameNRAuto
        case 0x02ffffff:
            self = .multiFrameNRHiAuto
        default:
            var buffer = ByteBuffer()
            buffer.append(DWord(binaryInt))
            guard let value = buffer[word: 0] else {
                return nil
            }
            guard let type = buffer[word: 2] else {
                self = .native(Int(value))
                return
            }
            switch type {
            case 0x0000:
                self = .native(Int(value))
            case 0x1000:
                self = .extended(Int(value))
            case 0x0100:
                self = .multiFrameNR(Int(value))
            case 0x0200:
                self = .multiFrameNRHi(Int(value))
            default:
                self = .native(Int(value))
            }
        }
    }
    
    var sonyPTPValue: PTPDevicePropertyDataType {
        switch self {
        case .auto:
            return DWord(0x00ffffff)
        case .multiFrameNRAuto:
            return DWord(0x01ffffff)
        case .multiFrameNRHiAuto:
            return DWord(0x02ffffff)
        case .extended(let value):
            var data = ByteBuffer()
            data.append(Word(value))
            data.append(Word(0x1000))
            return data[dWord: 0] ?? DWord(value)
        case .native(let value):
            var data = ByteBuffer()
            data.append(Word(value))
            data.append(Word(0x0000))
            return data[dWord: 0] ?? DWord(value)
        case .multiFrameNR(let value):
            var data = ByteBuffer()
            data.append(Word(value))
            data.append(Word(0x0100))
            return data[dWord: 0] ?? DWord(value)
        case .multiFrameNRHi(let value):
            var data = ByteBuffer()
            data.append(Word(value))
            data.append(Word(0x0200))
            return data[dWord: 0] ?? DWord(value)
        }
    }
}
