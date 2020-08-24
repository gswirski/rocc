//
//  Apeture.swift
//  Rocc
//
//  Created by Simon Mitchell on 26/04/2018.
//  Copyright © 2018 Simon Mitchell. All rights reserved.
//

import Foundation

/// Functions for interacting with the focal settings of the camera
public struct Focus {
    
    /// Functions for controlling the focus mode of the camera
    public struct Mode: CameraFunction {
        
        public enum Value: Equatable {
            case auto
            case autoSingle
            case autoContinuous
            case directManual
            case manual
            
            var isAutoFocus: Bool {
                return [.auto, .autoSingle, .autoContinuous].contains(self)
            }
        }
    
        public var function: _CameraFunction
        
        public typealias SendType = Value
        
        public typealias ReturnType = Value
        
        /// Sets the focus mode of the camera
        public static let set = Mode(function: .setFocusMode)
        
        /// Returns the current focus mode of the camera
        public static let get = Mode(function: .getFocusMode)
    }
}

extension Focus.Mode.Value: Codable {
    enum CodingKeys: CodingKey {
        case type
        case value
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(String.self, forKey: .type)
        
        switch type {
        case "AF-A": self = .auto
        case "AF-S": self = .autoSingle
        case "AF-C": self = .autoContinuous
        case "DMF": self = .directManual
        case "MF": self = .manual
        default:
            throw DecodingError .dataCorrupted(DecodingError .Context(codingPath: [CodingKeys.type], debugDescription: "invalid type"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .auto:
            try container.encode("AF-A", forKey: .type)
        case .autoSingle:
            try container.encode("AF-S", forKey: .type)
        case .autoContinuous:
            try container.encode("AF-C", forKey: .type)
        case .directManual:
            try container.encode("DMF", forKey: .type)
        case .manual:
            try container.encode("MF", forKey: .type)
        }
    }
    
}
