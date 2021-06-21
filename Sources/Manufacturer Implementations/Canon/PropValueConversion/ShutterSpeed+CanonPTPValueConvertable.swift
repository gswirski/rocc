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
    0x10: ShutterSpeed.Value(numerator: 300, denominator: 10, id: 0x10),
    0x13: ShutterSpeed.Value(numerator: 250, denominator: 10, id: 0x13),
    0x14: ShutterSpeed.Value(numerator: 200, denominator: 10, id: 0x14),
    0x15: ShutterSpeed.Value(numerator: 200, denominator: 10, id: 0x15),
    0x18: ShutterSpeed.Value(numerator: 150, denominator: 10, id: 0x18),
    0x1b: ShutterSpeed.Value(numerator: 130, denominator: 10, id: 0x1b),
    0x1c: ShutterSpeed.Value(numerator: 100, denominator: 10, id: 0x1c),
    
    0x1d: ShutterSpeed.Value(numerator: 100, denominator: 10, id: 0x1d),
    0x20: ShutterSpeed.Value(numerator: 80, denominator: 10, id: 0x20),
    0x23: ShutterSpeed.Value(numerator: 60, denominator: 10, id: 0x23),
    0x24: ShutterSpeed.Value(numerator: 60, denominator: 10, id: 0x24),
    
    0x25: ShutterSpeed.Value(numerator: 50, denominator: 10, id: 0x25),
    0x28: ShutterSpeed.Value(numerator: 40, denominator: 10, id: 0x28),
    0x2b: ShutterSpeed.Value(numerator: 32, denominator: 10, id: 0x2b),
    0x2c: ShutterSpeed.Value(numerator: 30, denominator: 10, id: 0x2c),
    
    0x2d: ShutterSpeed.Value(numerator: 25, denominator: 10, id: 0x2d),
    0x30: ShutterSpeed.Value(numerator: 20, denominator: 10, id: 0x30),
    0x33: ShutterSpeed.Value(numerator: 16, denominator: 10, id: 0x33),
    0x34: ShutterSpeed.Value(numerator: 15, denominator: 10, id: 0x34),
    
    0x35: ShutterSpeed.Value(numerator: 13, denominator: 10, id: 0x35),
    0x38: ShutterSpeed.Value(numerator: 10, denominator: 10, id: 0x38),
    0x3b: ShutterSpeed.Value(numerator: 8, denominator: 10, id: 0x3b),
    0x3c: ShutterSpeed.Value(numerator: 7, denominator: 10, id: 0x3c),
    
    0x3d: ShutterSpeed.Value(numerator: 6, denominator: 10, id: 0x3d),
    0x40: ShutterSpeed.Value(numerator: 5, denominator: 10, id: 0x40),
    0x43: ShutterSpeed.Value(numerator: 4, denominator: 10, id: 0x43),
    0x44: ShutterSpeed.Value(numerator: 3, denominator: 10, id: 0x44),

    0x45: ShutterSpeed.Value(numerator: 3, denominator: 10, id: 0x45),
    0x48: ShutterSpeed.Value(numerator: 1, denominator: 4, id: 0x48),
    0x4b: ShutterSpeed.Value(numerator: 1, denominator: 5, id: 0x4b),
    0x4c: ShutterSpeed.Value(numerator: 1, denominator: 6, id: 0x4c),

    0x4d: ShutterSpeed.Value(numerator: 1, denominator: 6, id: 0x4d),
    0x50: ShutterSpeed.Value(numerator: 1, denominator: 8, id: 0x50),
    0x53: ShutterSpeed.Value(numerator: 1, denominator: 10, id: 0x53),
    0x54: ShutterSpeed.Value(numerator: 1, denominator: 10, id: 0x54),

    0x55: ShutterSpeed.Value(numerator: 1, denominator: 13, id: 0x55),
    0x58: ShutterSpeed.Value(numerator: 1, denominator: 15, id: 0x58),
    0x5b: ShutterSpeed.Value(numerator: 1, denominator: 20, id: 0x5b),
    0x5c: ShutterSpeed.Value(numerator: 1, denominator: 20, id: 0x5c),

    0x5d: ShutterSpeed.Value(numerator: 1, denominator: 25, id: 0x5d),
    0x60: ShutterSpeed.Value(numerator: 1, denominator: 30, id: 0x60),
    0x63: ShutterSpeed.Value(numerator: 1, denominator: 40, id: 0x63),
    0x64: ShutterSpeed.Value(numerator: 1, denominator: 45, id: 0x64),

    
    0x65: ShutterSpeed.Value(numerator: 1, denominator: 50, id: 0x65),
    0x68: ShutterSpeed.Value(numerator: 1, denominator: 60, id: 0x68),
    0x6b: ShutterSpeed.Value(numerator: 1, denominator: 80, id: 0x6b),
    0x6c: ShutterSpeed.Value(numerator: 1, denominator: 90, id: 0x6c),

    0x6d: ShutterSpeed.Value(numerator: 1, denominator: 100, id: 0x6d),
    0x70: ShutterSpeed.Value(numerator: 1, denominator: 125, id: 0x70),
    0x73: ShutterSpeed.Value(numerator: 1, denominator: 160, id: 0x73),
    0x74: ShutterSpeed.Value(numerator: 1, denominator: 180, id: 0x74),
    
    0x75: ShutterSpeed.Value(numerator: 1, denominator: 200, id: 0x75),
    0x78: ShutterSpeed.Value(numerator: 1, denominator: 250, id: 0x78),
    0x7b: ShutterSpeed.Value(numerator: 1, denominator: 320, id: 0x7b),
    0x7c: ShutterSpeed.Value(numerator: 1, denominator: 350, id: 0x7c),
    
    0x7d: ShutterSpeed.Value(numerator: 1, denominator: 400, id: 0x7d),
    0x80: ShutterSpeed.Value(numerator: 1, denominator: 500, id: 0x80),
    0x83: ShutterSpeed.Value(numerator: 1, denominator: 640, id: 0x83),
    0x84: ShutterSpeed.Value(numerator: 1, denominator: 750, id: 0x84),
    
    0x85: ShutterSpeed.Value(numerator: 1, denominator: 800, id: 0x85),
    0x88: ShutterSpeed.Value(numerator: 1, denominator: 1000, id: 0x88),
    0x8b: ShutterSpeed.Value(numerator: 1, denominator: 1250, id: 0x8b),
    0x8c: ShutterSpeed.Value(numerator: 1, denominator: 1500, id: 0x8c),
    
    0x8d: ShutterSpeed.Value(numerator: 1, denominator: 1600, id: 0x8d),
    0x90: ShutterSpeed.Value(numerator: 1, denominator: 2000, id: 0x90),
    0x93: ShutterSpeed.Value(numerator: 1, denominator: 2500, id: 0x93),
    0x94: ShutterSpeed.Value(numerator: 1, denominator: 3000, id: 0x94),
    
    0x95: ShutterSpeed.Value(numerator: 1, denominator: 3200, id: 0x95),
    0x98: ShutterSpeed.Value(numerator: 1, denominator: 4000, id: 0x98),
    0x9b: ShutterSpeed.Value(numerator: 1, denominator: 5000, id: 0x9b),
    0x9c: ShutterSpeed.Value(numerator: 1, denominator: 6000, id: 0x9c),
    
    0x9d: ShutterSpeed.Value(numerator: 1, denominator: 6400, id: 0x9d),
    0xa0: ShutterSpeed.Value(numerator: 1, denominator: 8000, id: 0xa0),
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
            return value.id
        }
    }
    
    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xD102)
    }
}
