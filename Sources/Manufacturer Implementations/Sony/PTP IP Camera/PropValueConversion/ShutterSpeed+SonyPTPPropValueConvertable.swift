//
//  ShutterSpeed+SonyPTPPropValueConvertable.swift
//  Rocc
//
//  Created by Simon Mitchell on 08/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation

extension ShutterSpeed: SonyPTPPropValueConvertable {
    
    var type: PTP.DeviceProperty.DataType {
        return .uint32
    }
    
    var code: PTP.DeviceProperty.Code {
        return .shutterSpeed
    }
    
    init?(sonyValue: PTPDevicePropertyDataType) {
        
        guard let binaryInt = sonyValue.toInt else {
            return nil
        }
        
        var buffer = ByteBuffer()
        buffer.append(DWord(binaryInt))
        guard let denominator = buffer[word: 0] else {
            return nil
        }
        guard let numerator = buffer[word: 2] else {
            return nil
        }
        
        let value = ShutterSpeed.Value(numerator: Double(numerator), denominator: Double(denominator))
        self = .userDefined(value: value)
    }
    
    var sonyPTPValue: PTPDevicePropertyDataType {
        var data = ByteBuffer()
        // isBulb can be 0/0 or -1/-1 but PTP IP uses 0/0
        if case .bulb = self {
            data.append(Word(0))
            data.append(Word(0))
        } else if case .userDefined(let value) = self  {
            data.append(Word(value.denominator))
            data.append(Word(value.numerator))
        } else {
            fatalError("Sony only supports user defined values")
        }
        return data[dWord: 0]!
    }
}
