//
//  ShootingMode+CanonPTPValueConvertable.swift
//  Rocc
//
//  Created by Grzegorz Świrski on 03/05/2021.
//  Copyright © 2021 Simon Mitchell. All rights reserved.
//

import Foundation

extension ShootingMode: CanonPTPPropValueConvertable {
    var type: PTP.DeviceProperty.DataType {
        return .uint32
    }
    
    var code: PTP.DeviceProperty.Code {
        return .stillCaptureMode
    }
    

    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xd106)
    }
    
    init?(canonValue: PTPDevicePropertyDataType) {
        guard let binaryInt = canonValue.toInt else {
            return nil
        }
        
        /*
         0x11 - 2s self timer
         0x10 - 10s self timer
         0x05 - cont low
         0x04 - cont high
         0x12 - cont h plus
         0x00 - single

         Canon M50 also has 0x07.. - continuous custom
         Canon M100 has 0x01.  — continuous 6.1 fps AF-S, 4fps AF-C
         Canon 5Ds R 0x13 & 0x14 - silent single, silent continuous
         */
        switch binaryInt {
        case 0x00, 0x10, 0x11, 0x13:
            self = .photo
        case 0x01, 0x04, 0x05, 0x07, 0x12, 0x14:
            self = .continuous
        default:
            print("[EXPOSURE MODE] Unknown exposure mode: \(binaryInt)")
            return nil
        }
    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        switch self {
        case .photo:
            return DWord(0x00)
        case .continuous:
            return DWord(0x05)
        default:
            return DWord(0x00)
        }
    }
}
