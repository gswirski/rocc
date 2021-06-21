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

struct ApertureOption {
    let value: Double
    let id: UInt32
}

let APERTURE_AUTO_VALUE: DWord = 0xff
let canonApertureMapping: [DWord: ApertureOption] = [
    0x08: ApertureOption(value: 1, id: 0x08),
    0x0b: ApertureOption(value: 1.1, id: 0x0b),
    0x0c: ApertureOption(value: 1.2, id: 0x0c),
    0x0d: ApertureOption(value: 1.2, id: 0x0d),
    0x10: ApertureOption(value: 1.4, id: 0x10),
    0x13: ApertureOption(value: 1.6, id: 0x13),
    0x14: ApertureOption(value: 1.8, id: 0x14),
    0x15: ApertureOption(value: 1.8, id: 0x15),
    0x18: ApertureOption(value: 2.0, id: 0x18),
    0x1b: ApertureOption(value: 2.2, id: 0x1b),
    0x1c: ApertureOption(value: 2.5, id: 0x1c),
    0x1d: ApertureOption(value: 2.5, id: 0x1d),
    0x20: ApertureOption(value: 2.8, id: 0x20),
    0x23: ApertureOption(value: 3.2, id: 0x23),
    0x24: ApertureOption(value: 3.5, id: 0x24),
    0x25: ApertureOption(value: 3.5, id: 0x25),
    0x28: ApertureOption(value: 4.0, id: 0x28),
    0x2b: ApertureOption(value: 4.5, id: 0x2b),
    0x2c: ApertureOption(value: 4.5, id: 0x2c),
    0x2d: ApertureOption(value: 5.0, id: 0x2d),
    0x30: ApertureOption(value: 5.6, id: 0x30),
    0x33: ApertureOption(value: 6.3, id: 0x33),
    0x34: ApertureOption(value: 6.7, id: 0x34),
    0x35: ApertureOption(value: 7.1, id: 0x35),
    0x38: ApertureOption(value: 8, id: 0x38),
    0x3b: ApertureOption(value: 9, id: 0x3b),
    0x3c: ApertureOption(value: 9.5, id: 0x3c),
    0x3d: ApertureOption(value: 10, id: 0x3d),
    0x40: ApertureOption(value: 11, id: 0x40),
    0x43: ApertureOption(value: 13, id: 0x43),
    0x44: ApertureOption(value: 13, id: 0x44),
    0x45: ApertureOption(value: 14, id: 0x45),
    0x48: ApertureOption(value: 16, id: 0x48),
    0x4b: ApertureOption(value: 18, id: 0x4b),
    0x4c: ApertureOption(value: 19, id: 0x4c),
    0x4d: ApertureOption(value: 20, id: 0x4d),
    0x50: ApertureOption(value: 22, id: 0x50),
    0x53: ApertureOption(value: 25, id: 0x53),
    0x54: ApertureOption(value: 27, id: 0x54),
    0x55: ApertureOption(value: 29, id: 0x55),
    0x58: ApertureOption(value: 32, id: 0x58),
    0x5b: ApertureOption(value: 36,	id: 0x5b),
    0x5c: ApertureOption(value: 38, id: 0x5c),
    0x5d: ApertureOption(value: 40, id: 0x5d),
    0x60: ApertureOption(value: 45, id: 0x60),
    0x63: ApertureOption(value: 51, id: 0x63),
    0x64: ApertureOption(value: 54, id: 0x64),
    0x65: ApertureOption(value: 57, id: 0x65),
    0x68: ApertureOption(value: 64, id: 0x68),
    0x6b: ApertureOption(value: 72, id: 0x6b),
    0x6c: ApertureOption(value: 76, id: 0x6c),
    0x6d: ApertureOption(value: 81, id: 0x6d),
    0x70: ApertureOption(value: 91, id: 0x70)
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
            if let olc = olcValue, let binaryOlc = olc.toInt, let item = canonApertureMapping[UInt32(binaryOlc)] {
                self = .auto(value: item.value, id: item.id)
                return
            } else {
                self = .auto(value: nil, id: nil)
                return
            }
        }

        let item = canonApertureMapping[UInt32(binaryInt)]!
        self = .userDefined(value: item.value, id: item.id)
    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        switch self {
        case .userDefined(let value, let id):
            return id
        case .auto(value: _, id: _):
            return APERTURE_AUTO_VALUE
        }
        
    }
    
    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xd101)
    }
}
