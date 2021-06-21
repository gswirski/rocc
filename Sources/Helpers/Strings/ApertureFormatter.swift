//
//  ApertureFormatter.swift
//  Rocc
//
//  Created by Simon Mitchell on 23/05/2020.
//  Copyright © 2020 Simon Mitchell. All rights reserved.
//

import Foundation

public class ApertureFormatter {
    public init() {
    }

    public func string(for obj: Aperture.Value?) -> String? {
        
        guard let aperture = obj else {
            return nil
        }
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.maximumFractionDigits = 1
        numberFormatter.decimalSeparator = "."
        
        switch aperture {
        case .userDefined(let value, let id):
            return numberFormatter.string(from: NSNumber(value: value))
        case .auto(let value, let id):
            if let actualValue = value {
                return numberFormatter.string(from: NSNumber(value: actualValue))
            } else {
                return "AUTO"
            }
        }
    }
    
    public func aperture(from string: String) -> Aperture.Value? {
        if string.lowercased() == "auto" {
            return .auto(value: nil, id: nil)
        }
        let numberFormatter = NumberFormatter()
        
        // Parse the decimal seperator, this will always be the last non-number character in the
        // aperture
        if let decimalSeperatorCharacter = string.last(where: { (character) -> Bool in
            return !character.isNumber
        }) {
            numberFormatter.decimalSeparator = String(decimalSeperatorCharacter)
        }
        
        guard let number = numberFormatter.number(from: string) else { return nil }
        
        return .userDefined(value: number.doubleValue, id: 0)
    }
}
