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

let canonIsoMapping: [DWord: Int] = [
    0x00: 0,
    0x40: 50,
    0x48: 100,
    0x4b: 125,
    0x4d: 160,
    0x50: 200,
    0x53: 250,
    0x55: 320,
    0x58: 400,
    0x5b: 500,
    0x5d: 640,
    0x60: 800,
    0x63: 1000,
    0x65: 1250,
    0x68: 1600,
    0x6b: 2000,
    0x6d: 2500,
    0x70: 3200,
    0x73: 4000,
    0x75: 5000,
    0x78: 6400,
    0x7b: 8000,
    0x7d: 10000,
    0x80: 12800,
    0x83: 16000,
    0x85: 20000,
    0x88: 25600,
    0x8b: 32000,
    0x8d: 40000,
    0x90: 51200,
    0x93: 64000,
    0x95: 80000,
    0x98: 102400,
]

extension ISO.Value: CanonPTPPropValueConvertable {
    init?(canonValue: PTPDevicePropertyDataType) {
        
        guard let binaryInt = canonValue.toInt else {
            return nil
        }
        guard let item = canonIsoMapping[UInt32(binaryInt)] else {
            print("Canon Invalid Value ISO \(binaryInt)")
            return nil
        }
        
        if item == 0 {
            self = .auto
        } else {
            self = .native(item)
        }
    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        return canonIsoMapping.first { (item) -> Bool in
            let value = item.1
            switch self {
            case .auto:
                return value == 0
            case .native(let x):
                return value == x
            default:
                return false
            }
        }!.key
    }
    
    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xD103)
    }
}
