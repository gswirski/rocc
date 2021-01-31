//
//  CanonPTPLiveStreamingTests.swift
//  RoccTests
//
//  Created by Grzegorz Świrski on 29/01/2021.
//  Copyright © 2021 Simon Mitchell. All rights reserved.
//

import XCTest
@testable import Rocc

enum VendingMachineError: Error {
    case invalidSelection
    case insufficientFunds(coinsNeeded: Int)
    case outOfStock
}


class CanonPTPLiveStreamingTests: XCTestCase {

    func testCanonLiveViewParsesCorrectly() {
        guard let hexString = try? String(contentsOf: Bundle(for: LiveViewStreamingTests.self).url(forResource: "liveview-r6-singleimage", withExtension: nil)!) else {
            XCTFail("Couldn't get hex string from file: liveview-rx100m7-singleimage")
            return
        }
        
        let byteBuffer = ByteBuffer(hexString: hexString)

        var pointer: UInt = 0
        let len = byteBuffer[dWord: pointer]!
        let type = byteBuffer[dWord: pointer+4]!
        
        let data = Data(byteBuffer.sliced(8, 8+Int(len)))
        let image = UIImage(data: data)!
        
        let url = try! getCacheDirectory()
        let path = url.appendingPathComponent("preview.jpeg")
        let jpegData = UIImageJPEGRepresentation(image, 1)
        try! jpegData?.write(to: path)
        
        print("byte count \(byteBuffer.length) len \(len) type: \(type) img: \(image) URL \(url)")
    }
    
    func getCacheDirectory() throws -> URL {
        let cachePath = "Desktop"
        // on OSX config is stored in /Users/<username>/Library
        // and on iOS/tvOS/WatchOS it's in simulator's home dir
        #if os(OSX)
            let homeDir = URL(fileURLWithPath: NSHomeDirectory())
            return homeDir.appendingPathComponent(cachePath)
        #elseif arch(i386) || arch(x86_64)
            guard let simulatorHostHome = ProcessInfo().environment["SIMULATOR_HOST_HOME"] else {
                throw VendingMachineError.outOfStock
            }
            let homeDir = URL(fileURLWithPath: simulatorHostHome)
            return homeDir.appendingPathComponent(cachePath)
        #else
            throw SnapshotError.cannotRunOnPhysicalDevice
        #endif
    }

}
