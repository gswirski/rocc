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

let SHUTTER_SPEED_AUTO_VALUE: DWord = 0x04
let canonShutterSpeedMapping: [DWord: ShutterSpeed.Value] = [
    0x10: ShutterSpeed.Value(numerator: 300, denominator: 10),
    0x13: ShutterSpeed.Value(numerator: 250, denominator: 10),
    0x15: ShutterSpeed.Value(numerator: 200, denominator: 10),
    0x18: ShutterSpeed.Value(numerator: 150, denominator: 10),
    0x1b: ShutterSpeed.Value(numerator: 130, denominator: 10),
    0x1d: ShutterSpeed.Value(numerator: 100, denominator: 10),
    0x20: ShutterSpeed.Value(numerator: 80, denominator: 10),
    0x23: ShutterSpeed.Value(numerator: 60, denominator: 10),
    0x25: ShutterSpeed.Value(numerator: 50, denominator: 10),
    0x28: ShutterSpeed.Value(numerator: 40, denominator: 10),
    0x2b: ShutterSpeed.Value(numerator: 32, denominator: 10),
    0x2d: ShutterSpeed.Value(numerator: 25, denominator: 10),
    0x30: ShutterSpeed.Value(numerator: 20, denominator: 10),
    0x33: ShutterSpeed.Value(numerator: 16, denominator: 10),
    0x35: ShutterSpeed.Value(numerator: 13, denominator: 10),
    0x38: ShutterSpeed.Value(numerator: 10, denominator: 10),
    0x3b: ShutterSpeed.Value(numerator: 8, denominator: 10),
    0x3d: ShutterSpeed.Value(numerator: 6, denominator: 10),
    0x40: ShutterSpeed.Value(numerator: 5, denominator: 10),
    0x43: ShutterSpeed.Value(numerator: 4, denominator: 10),
    0x45: ShutterSpeed.Value(numerator: 3, denominator: 10),
    0x48: ShutterSpeed.Value(numerator: 1, denominator: 4),
    0x4b: ShutterSpeed.Value(numerator: 1, denominator: 5),
    0x4d: ShutterSpeed.Value(numerator: 1, denominator: 6),
    0x50: ShutterSpeed.Value(numerator: 1, denominator: 8),
    0x53: ShutterSpeed.Value(numerator: 1, denominator: 10),
    0x55: ShutterSpeed.Value(numerator: 1, denominator: 13),
    0x58: ShutterSpeed.Value(numerator: 1, denominator: 15),
    0x5b: ShutterSpeed.Value(numerator: 1, denominator: 20),
    0x5d: ShutterSpeed.Value(numerator: 1, denominator: 25),
    0x60: ShutterSpeed.Value(numerator: 1, denominator: 30),
    0x63: ShutterSpeed.Value(numerator: 1, denominator: 40),
    0x65: ShutterSpeed.Value(numerator: 1, denominator: 50),
    0x68: ShutterSpeed.Value(numerator: 1, denominator: 60),
    0x6b: ShutterSpeed.Value(numerator: 1, denominator: 80),
    0x6d: ShutterSpeed.Value(numerator: 1, denominator: 100),
    0x70: ShutterSpeed.Value(numerator: 1, denominator: 125),
    0x73: ShutterSpeed.Value(numerator: 1, denominator: 160),
    0x75: ShutterSpeed.Value(numerator: 1, denominator: 200),
    0x78: ShutterSpeed.Value(numerator: 1, denominator: 250),
    0x7b: ShutterSpeed.Value(numerator: 1, denominator: 320),
    0x7d: ShutterSpeed.Value(numerator: 1, denominator: 400),
    0x80: ShutterSpeed.Value(numerator: 1, denominator: 500),
    0x83: ShutterSpeed.Value(numerator: 1, denominator: 640),
    0x85: ShutterSpeed.Value(numerator: 1, denominator: 800),
    0x88: ShutterSpeed.Value(numerator: 1, denominator: 1000),
    0x8b: ShutterSpeed.Value(numerator: 1, denominator: 1250),
    0x8d: ShutterSpeed.Value(numerator: 1, denominator: 1600),
    0x90: ShutterSpeed.Value(numerator: 1, denominator: 2000),
    0x93: ShutterSpeed.Value(numerator: 1, denominator: 2500),
    0x95: ShutterSpeed.Value(numerator: 1, denominator: 3200),
    0x98: ShutterSpeed.Value(numerator: 1, denominator: 4000),
    0x9b: ShutterSpeed.Value(numerator: 1, denominator: 5000),
    0x9d: ShutterSpeed.Value(numerator: 1, denominator: 6400),
    0xa0: ShutterSpeed.Value(numerator: 1, denominator: 8000),
]

extension ShutterSpeed: CanonPTPPropValueConvertable {
    init?(canonValue: PTPDevicePropertyDataType) {
        self.init(canonValue: canonValue, olcValue: nil)
    }
    
    init?(canonValue: PTPDevicePropertyDataType, olcValue: PTPDevicePropertyDataType? = nil) {
        
        guard let binaryInt = canonValue.toInt else {
            return nil
        }
        
        guard binaryInt != SHUTTER_SPEED_AUTO_VALUE else {
            if let olc = olcValue, let binaryOlc = olc.toInt {
                if let item = canonShutterSpeedMapping[UInt32(binaryOlc)] {
                   self = .auto(value: item)
                   return
                } else if binaryOlc == 0x0c {
                    self = .bulb
                    return
                } else {
                    self = .auto(value: nil)
                    return
                }
            } else {
                self = .auto(value: nil)
                return
            }
        }
        
        guard binaryInt != 0x0c else {
            self = .bulb
            return
        }
            
        let item = canonShutterSpeedMapping[UInt32(binaryInt)]!
        
        self = .userDefined(value: item)
    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        switch self {
        case .auto(_), .bulb:
            return SHUTTER_SPEED_AUTO_VALUE
        case .userDefined(value: let value):
            return canonShutterSpeedMapping.first { (item) -> Bool in
                let reference = item.1
                return value.numerator == reference.numerator && value.denominator == reference.denominator
            }!.key
        }
    }
    
    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xD102)
    }
}
