//
//  ISOValue+SonyPTPPropValueConvertible.swift
//  Rocc
//
//  Created by Simon Mitchell on 08/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation

extension Aperture.Value: SonyPTPPropValueConvertable {
    
    var type: PTP.DeviceProperty.DataType {
        return .uint16
    }
    
    var code: PTP.DeviceProperty.Code {
        return .fNumber
    }
    
    init?(sonyValue: PTPDevicePropertyDataType) {
        
        guard let binaryInt = sonyValue.toInt else {
            return nil
        }
        
        self = .userDefined(value: Double(binaryInt)/100.0, id: 0)
    }
    
    var sonyPTPValue: PTPDevicePropertyDataType {
        guard case let .userDefined(value, id) = self else {
            fatalError("Sony only supports user defined values")
        }
        return Word(value * 100)
    }
}
