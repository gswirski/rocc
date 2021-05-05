//
//  ShutterSpeedFormatter.swift
//  Rocc
//
//  Created by Simon Mitchell on 27/11/2018.
//  Copyright © 2018 Simon Mitchell. All rights reserved.
//

import Foundation

extension Double {
    var isInteger: Bool {
        return truncatingRemainder(dividingBy: 1) == 0
    }
}

/// A representation of shutter speed.
/// This must be stored as numerator and denominator so it can be re-constructed
/// into it's string format where needed without breaking fractional shutter speeds.
public enum ShutterSpeed: Equatable {
    case userDefined(value: Value)
    case auto(value: Value?)
    case bulb

    public struct Value: Equatable {
        /// The numerator of the shutter speed
        public let numerator: Double
        
        /// The denominator of the shutter speed
        public let denominator: Double
        
        /// Creates a new shutter speed with numerator and denominator
        ///
        /// - Parameters:
        ///   - numerator: The numerator for the shutter speed
        ///   - denominator: The denominator for the shutter speed
        public init(numerator: Double, denominator: Double) {
            self.numerator = numerator
            self.denominator = denominator
        }
        
        /// A statically available constant for BULB shutter speed
        public static let bulb: Value = Value(numerator: -1.0, denominator: -1.0)
        
        /// Returns whether the given shutter speed is a BULB shutter speed
        public var isBulb: Bool {
            return (denominator == -1.0 || numerator == -1.0) || (denominator == 0 && numerator == 0)
        }
        
        public static func ==(lhs: Value, rhs: Value) -> Bool {
            return lhs.numerator == rhs.numerator && lhs.denominator == rhs.denominator && lhs.isBulb == rhs.isBulb
        }
    }
}

extension Double {
    var toString: String {
        return isInteger ? "\(Int(self))" : "\(self)"
    }
}

/// A formatter that converts between shutter speeds and their text format
public class ShutterSpeedFormatter {
    
    /// Formatting options for use with `ShutterSpeedFormatter`
    public struct FormattingOptions: OptionSet {
        
        public let rawValue: Int
        
        /// Whether to append quotes for shutter speeds over 1 second
        static let appendQuotes = FormattingOptions(rawValue: 1 << 0)
        
        /// Whether integers should be formatted with decimal places included
        static let forceIntegersToDouble = FormattingOptions(rawValue: 2 << 0)
    
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    /// The options to use when formatting shutter speeds
    public var formattingOptions: FormattingOptions = [.appendQuotes]
    
    public init() {
        
    }
    
    /// Returns a formatted string for the given shutter speed using `formattingOptions`
    ///
    /// - Parameter shutterSpeed: The shutter speed to format to a string
    /// - Returns: The shutter speed formatted to a string
    public func string(from shutterSpeed: ShutterSpeed) -> String {
        guard shutterSpeed != .bulb else {
            return "BULB"
        }
    
        switch shutterSpeed {
        case .bulb: return "BULB"
        case .auto(let value):
            if let value = value {
                return string(from: value)
            } else {
                return "AUTO"
            }
        case .userDefined(let value):
            return string(from: value)
        }
        
    }
    
    private func string(from shutterSpeed: ShutterSpeed.Value) -> String {
        var fixedShutterSpeed = shutterSpeed
        
        let fixedValue = fixedShutterSpeed.numerator / fixedShutterSpeed.denominator
        // For some reason some cameras returns shutter speeds as 300/10 = 30 seconds.
        if fixedValue >= 1/3 {
            while fixedShutterSpeed.denominator >= 10, fixedShutterSpeed.denominator.remainder(dividingBy: 10) == 0 {
                fixedShutterSpeed = ShutterSpeed.Value(numerator: fixedShutterSpeed.numerator/10, denominator: fixedShutterSpeed.denominator/10)
            }
        }
        
        guard fixedShutterSpeed.denominator != 1 else {
            let fixedValue = fixedShutterSpeed.numerator / fixedShutterSpeed.denominator

            var string: String = ""
            if formattingOptions.contains(.forceIntegersToDouble) {
                string = "\(fixedValue)"
            } else {
                string = "\(fixedValue.toString)"
            }
            
            if formattingOptions.contains(.appendQuotes) {
                return "\(string)\""
            } else {
                return "\(string)"
            }
        }
        
        if formattingOptions.contains(.forceIntegersToDouble) {
            return "\(fixedShutterSpeed.numerator)/\(fixedShutterSpeed.denominator)"
        } else {
            return "\(fixedShutterSpeed.numerator.toString)/\(fixedShutterSpeed.denominator.toString)"
        }
    }
    
    /// Attempts to parse a shutter speed from a given string
    ///
    /// - Parameter string: The string representation of a shutter speed
    /// - Returns: A parsed shutter speed if one could be calculated
    public func shutterSpeed(from string: String) -> ShutterSpeed? {
        
        guard string.lowercased() != "bulb" else {
            return ShutterSpeed.bulb
        }
        
        let trimmedString = string.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
        
        if let timeInterval = TimeInterval(trimmedString) {
            return .userDefined(value: ShutterSpeed.Value(numerator: timeInterval, denominator: 1))
        }
        
        if let value = ShutterSpeed.Value(fractionString: trimmedString) {
            return .userDefined(value: value)
        } else {
            return nil
        }
    }
}

fileprivate extension ShutterSpeed.Value {
    
    init?(fractionString: String) {
        
        guard let fractionRegex = try? NSRegularExpression(pattern: "^(\\d*|\\d*\\.\\d*)\\/(\\d*|\\d*\\.\\d*)$", options: [.anchorsMatchLines]), let match = fractionRegex.firstMatch(in: fractionString, options: []
            , range: NSRange(fractionString.startIndex..., in: fractionString)) else {
            return nil
        }
        
        guard let numeratorRange = Range(match.range(at: 1), in: fractionString) else {
            return nil
        }
        guard let denominatorRange = Range(match.range(at: 2), in: fractionString) else {
            return nil
        }
        
        let numeratorString = fractionString[numeratorRange]
        let denominatorString = fractionString[denominatorRange]
        
        guard let numerator = Double(numeratorString) else { return nil }
        guard let denominator = Double(denominatorString) else { return nil }
        
        self.init(numerator: numerator, denominator: denominator)
    }
}
