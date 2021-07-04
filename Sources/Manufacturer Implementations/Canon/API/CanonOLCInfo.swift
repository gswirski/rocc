//
//  CanonOLCInfo.swift
//  Rocc
//
//  Created by Grzegorz Świrski on 01/05/2021.
//  Copyright © 2021 Simon Mitchell. All rights reserved.
//

import Foundation

struct CanonOLCInfo {
    var button: UInt8?
    var shutterSpeed: ByteBuffer?
    var aperture: ByteBuffer?
    var iso: ByteBuffer?
    var maybeMemoryStatus: ByteBuffer?
    var selfTimer: ByteBuffer?
    var exposureMeter: ByteBuffer?
    var unknown2: ByteBuffer?
    var focusInfo: ByteBuffer?
    var unknown3: ByteBuffer?
    var unknown4: ByteBuffer?
    var unknown5: ByteBuffer?
    
    init() {}
}
