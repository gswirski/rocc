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

let canonShutterSpeedMapping: [DWord: ShutterSpeed] = [
    0x04: ShutterSpeed(numerator: -1, denominator: -1), // BULB
    0x10: ShutterSpeed(numerator: 300, denominator: 10),
    0x13: ShutterSpeed(numerator: 250, denominator: 10),
    0x15: ShutterSpeed(numerator: 200, denominator: 10),
    0x18: ShutterSpeed(numerator: 150, denominator: 10),
    0x1b: ShutterSpeed(numerator: 130, denominator: 10),
    0x1d: ShutterSpeed(numerator: 100, denominator: 10),
    0x20: ShutterSpeed(numerator: 80, denominator: 10),
    0x23: ShutterSpeed(numerator: 60, denominator: 10),
    0x25: ShutterSpeed(numerator: 50, denominator: 10),
    0x28: ShutterSpeed(numerator: 40, denominator: 10),
    0x2b: ShutterSpeed(numerator: 32, denominator: 10),
    0x2d: ShutterSpeed(numerator: 25, denominator: 10),
    0x30: ShutterSpeed(numerator: 20, denominator: 10),
    0x33: ShutterSpeed(numerator: 16, denominator: 10),
    0x35: ShutterSpeed(numerator: 13, denominator: 10),
    0x38: ShutterSpeed(numerator: 10, denominator: 10),
    0x3b: ShutterSpeed(numerator: 8, denominator: 10),
    0x3d: ShutterSpeed(numerator: 6, denominator: 10),
    0x40: ShutterSpeed(numerator: 5, denominator: 10),
    0x43: ShutterSpeed(numerator: 4, denominator: 10),
    0x45: ShutterSpeed(numerator: 3, denominator: 10),
    0x48: ShutterSpeed(numerator: 1, denominator: 4),
    0x4b: ShutterSpeed(numerator: 1, denominator: 5),
    0x4d: ShutterSpeed(numerator: 1, denominator: 6),
    0x50: ShutterSpeed(numerator: 1, denominator: 8),
    0x53: ShutterSpeed(numerator: 1, denominator: 10),
    0x55: ShutterSpeed(numerator: 1, denominator: 13),
    0x58: ShutterSpeed(numerator: 1, denominator: 15),
    0x5b: ShutterSpeed(numerator: 1, denominator: 20),
    0x5d: ShutterSpeed(numerator: 1, denominator: 25),
    0x60: ShutterSpeed(numerator: 1, denominator: 30),
    0x63: ShutterSpeed(numerator: 1, denominator: 40),
    0x65: ShutterSpeed(numerator: 1, denominator: 50),
    0x68: ShutterSpeed(numerator: 1, denominator: 60),
    0x6b: ShutterSpeed(numerator: 1, denominator: 80),
    0x6d: ShutterSpeed(numerator: 1, denominator: 100),
    0x70: ShutterSpeed(numerator: 1, denominator: 125),
    0x73: ShutterSpeed(numerator: 1, denominator: 160),
    0x75: ShutterSpeed(numerator: 1, denominator: 200),
    0x78: ShutterSpeed(numerator: 1, denominator: 250),
    0x7b: ShutterSpeed(numerator: 1, denominator: 320),
    0x7d: ShutterSpeed(numerator: 1, denominator: 400),
    0x80: ShutterSpeed(numerator: 1, denominator: 500),
    0x83: ShutterSpeed(numerator: 1, denominator: 640),
    0x85: ShutterSpeed(numerator: 1, denominator: 800),
    0x88: ShutterSpeed(numerator: 1, denominator: 1000),
    0x8b: ShutterSpeed(numerator: 1, denominator: 1250),
    0x8d: ShutterSpeed(numerator: 1, denominator: 1600),
    0x90: ShutterSpeed(numerator: 1, denominator: 2000),
    0x93: ShutterSpeed(numerator: 1, denominator: 2500),
    0x95: ShutterSpeed(numerator: 1, denominator: 3200),
    0x98: ShutterSpeed(numerator: 1, denominator: 4000),
    0x9b: ShutterSpeed(numerator: 1, denominator: 5000),
    0x9d: ShutterSpeed(numerator: 1, denominator: 6400),
    0xa0: ShutterSpeed(numerator: 1, denominator: 8000),
]

extension ShutterSpeed: CanonPTPPropValueConvertable {
    init?(canonValue: PTPDevicePropertyDataType) {
        
        guard let binaryInt = canonValue.toInt else {
            return nil
        }
        
        let item = canonShutterSpeedMapping[UInt32(binaryInt), default: ShutterSpeed(numerator: -2, denominator: -2)]
        
        if item.numerator == -2 {
            print("Canon Invalid Value Shutter Speed \(binaryInt)")
            return nil
        }
        
        numerator = item.numerator
        denominator = item.denominator
    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        return canonShutterSpeedMapping.first { (item) -> Bool in
            let value = item.1
            return value.numerator == self.numerator && value.denominator == self.denominator
        }!.key
    }
    
    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xD102)
    }
}
