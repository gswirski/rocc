//
//  ApertureValue+CanonPTPValueConvertable.swift
//  Rocc
//
//  Created by Grzegorz Świrski on 21/01/2021.
//  Copyright © 2021 Simon Mitchell. All rights reserved.
//

import Foundation

/**
 *
 * the formula:
 * 2^([x-24]/8)
 *
 * for x = 0x10 = 16   -> 1/2
 * for x = 0x18 = 24   -> 2^3 = 8
*/

let canonExposureCompensationMapping: [DWord: Double] = [
    0x18: 3,
    0x15: 2 + 2.0/3,
    0x14: 2 + 1.0/2,
    0x13: 2 + 1.0/3,
    0x10: 2,
    0x0d: 1 + 2.0/3,
    0x0c: 1 + 1.0/2,
    0x0b: 1 + 1.0/3,
    0x08: 1,
    0x05: 2.0/3,
    0x04: 1.0/2,
    0x03: 1.0/3,
    0x00: 0,
    0xfd: -1.0/3,
    0xfc: -1.0/2,
    0xfb: -2.0/3,
    0xf8: -1,
    0xf5: -1 - 1.0/3,
    0xf4: -1 - 1.0/2,
    0xf3: -1 - 2.0/3,
    0xf0: -2,
    0xed: -2 - 1.0/3,
    0xec: -2 - 1.0/2,
    0xeb: -2 - 2.0/3,
    0xe8: -3
]

extension Exposure.Compensation.Value: CanonPTPPropValueConvertable {
    init?(canonValue: PTPDevicePropertyDataType) {
        
        guard let binaryInt = canonValue.toInt else {
            return nil
        }

        guard let item = canonExposureCompensationMapping[UInt32(binaryInt)] else {
            print("Canon Invalid Value Exp Comp \(binaryInt)")
            return nil
        }
        
        value = item

    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        return canonExposureCompensationMapping.first { (item) -> Bool in
            let value = item.1
            return abs(value - self.value) < 0.001
        }!.key
    }
    
    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xD104)
    }
}
