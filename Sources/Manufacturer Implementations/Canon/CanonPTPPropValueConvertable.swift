//
//  CanonPTPPropValueConvertable.swift
//  Rocc
//
//  Created by Grzegorz Świrski on 21/01/2021.
//  Copyright © 2021 Simon Mitchell. All rights reserved.
//

protocol CanonPTPPropValueConvertable {
    
    var canonPTPValue: PTPDevicePropertyDataType { get }
    
    var canonPTPCode: PTPDevicePropertyDataType { get }

    var type: PTP.DeviceProperty.DataType { get }
    
    var code: PTP.DeviceProperty.Code { get }
    
    init?(sonyValue: PTPDevicePropertyDataType)
}
