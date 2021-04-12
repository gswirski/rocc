//
//  ExposureMode+SonyPTPPropValueConvertible.swift
//  Rocc
//
//  Created by Simon Mitchell on 08/11/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import Foundation

extension Exposure.Mode.Value: CanonPTPPropValueConvertable {

    var canonPTPCode: PTPDevicePropertyDataType {
        return UInt32(0xd105)
    }
    
    init?(canonValue: PTPDevicePropertyDataType) {
        guard let binaryInt = canonValue.toInt else {
            return nil
        }
        
        /*
         B - 4
         M - 3
         Av - 2
         Tv - 1
         P - 0
         Fv - 55
         A+ 22
         */
        switch binaryInt {
        case 0x04:
            self = .bulb
        case 0x03:
            self = .manual
        case 0x02:
            self = .aperturePriority
        case 0x01:
            self = .shutterPriority
        case 0x00:
            self = .programmedAuto
        case 0x37:
            self = .flexiblePriority
        case 0x16:
            self = .intelligentAuto
        default:
            print("[EXPOSURE MODE] Unknown exposure mode: \(binaryInt)")
            return nil
        }
    }
    
    var canonPTPValue: PTPDevicePropertyDataType {
        switch self {
        /*case .bulb:
            self = .manual // TODO: implement BULB*/
        case .manual:
            return DWord(0x03)
        case .aperturePriority:
            return DWord(0x02)
        case .shutterPriority:
            return DWord(0x01)
        case .programmedAuto:
            return DWord(0x00)
        case .superiorAuto:
            return DWord(0x37) // TODO: implement Fv
        case .intelligentAuto:
            return DWord(0x16)
        default:
            return DWord(0x00)
        }
    }
}
