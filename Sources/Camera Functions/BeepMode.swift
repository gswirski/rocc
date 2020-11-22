//
//  Apeture.swift
//  Rocc
//
//  Created by Simon Mitchell on 26/04/2018.
//  Copyright © 2018 Simon Mitchell. All rights reserved.
//

import Foundation

/// Functions for configuring the beep mode of the camera
public struct BeepMode: CameraFunction {
    
    public var function: _CameraFunction
    
    public typealias SendType = String
    
    public typealias ReturnType = String
    
    /// Sets the beep mode of the camera
    public static let set = BeepMode(function: .setBeepMode)
    
    /// Returns the current beep mode of the camera
    public static let get = BeepMode(function: .getBeepMode)
}
