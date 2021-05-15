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

let APERTURE_AUTO_VALUE: DWord = 0xff
let canonApertureMapping: [Double: DWord] = [
    1.2: 0x0d,
    1.4: 0x10,
    1.6: 0x13,
    1.8: 0x15,
    2.0: 0x18,
    2.2: 0x1b,
    2.5: 0x1d,
    2.8: 0x20,
    3.2: 0x23,
    3.5: 0x25,
    4.0: 0x28,
    4.5: 0x2b,
    5.0: 0x2d,
    5.6: 0x30,
    6.3: 0x33,
    7.1: 0x35,
    8: 0x38,
    9: 0x3b,
    10: 0x3d,
    11: 0x40,
    13: 0x43,
    14: 0x45,
    16: 0x48,
    18: 0x4b,
    20: 0x4d,
    22: 0x50,
    25: 0x53,
    29: 0x55,
    32: 0x58
]

extension Aperture.Value: CanonPTPPropValueConvertable {
    init?(canonValue: PTPDevicePropertyDataType) {
        self.init(canonValue: canonValue, olcValue: nil)
    }

    init?(canonValue: PTPDevicePropertyDataType, olcValue: PTPDevicePropertyDataType? = nil) {
        
        guard let binaryInt = canonValue.toInt else {
            return nil
        }
        
        guard binaryInt != APERTURE_AUTO_VALUE else {
            if let olc = olcValue, let binaryOlc = olc.toInt, let item = canonApertureMapping.first(where: { (key, val) -> Bool in val == binaryOlc}) {
                self = .auto(value: item.key)
                return
            } else {
                self = .auto(value: nil)
                return
            }
        }

        guard let item = canonApertureMapping.first(where: { (key, val) -> Bool in
            val == binaryInt
        }) else {
            return nil
        }
        
        self = .userDefined(value: item.key)
    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        switch self {
        case .userDefined(let value):
            return canonApertureMapping[value]!
        case .auto(value: _):
            return APERTURE_AUTO_VALUE
        }
        
    }
    
    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xd101)
    }
}
