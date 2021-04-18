//
//  LiveViewStreamingTests.swift
//  RoccTests
//
//  Created by Simon Mitchell on 09/12/2019.
//  Copyright © 2019 Simon Mitchell. All rights reserved.
//

import XCTest
@testable import Rocc


class LiveViewStreamingTests: XCTestCase {

    func testCanonR6LiveViewDataParsedCorrectly() {
        guard let hexString = try? String(contentsOf: Bundle(for: LiveViewStreamingTests.self).url(forResource: "liveview-focus-9-points.txt", withExtension: nil)!) else {
            XCTFail("Couldn't get hex string from file: liveview-rx100m7-singleimage")
            return
        }
        
        let byteBuffer = ByteBuffer(hexString: hexString)
        
        let dataSize = byteBuffer.length
        var pointer: UInt = 0
        
        while (pointer + 8 < dataSize) {
            let size: DWord? = byteBuffer[dWord: pointer]
            let type: DWord? = byteBuffer[dWord: pointer + 4]
            
            switch type {
            case 1, 9, 11:
                print("field JPEG size: \(size) type: \(type)")
            case 14:
                let width = byteBuffer[dWord: pointer + 8]
                let height = byteBuffer[dWord: pointer + 12]
                print("field viewfinder size \(width) \(height)")
            case 8:
                let points = byteBuffer[dWord: pointer + 8]!
                let frames = (1...points).map { (index) -> FrameInfo? in
                    let start = Int(pointer) + (Int(index)-1) * 24 + 12
                    let frame = FrameInfo(canonData: byteBuffer.sliced(start, start + 24), viewfinder: (width: 100, height: 100))
                    
                    return frame
                }
                print("field focus \(frames)")
            default:
                print("field unknown size: \(size) type: \(type)")
            }
                        
            pointer += UInt(size!)
        }
    }
    
    func testRX100M7SingleImageDataIsParsedCorrectly() {
        
        guard let hexString = try? String(contentsOf: Bundle(for: LiveViewStreamingTests.self).url(forResource: "liveview-rx100m7-singleimage", withExtension: nil)!) else {
            XCTFail("Couldn't get hex string from file: liveview-rx100m7-singleimage")
            return
        }
        
        let byteBuffer = ByteBuffer(hexString: hexString)
        let data = Data(bytes: byteBuffer.bytes.compactMap({ $0 }))
        let liveViewStream = LiveViewStream(camera: DummyCamera(), delegate: nil)
        liveViewStream.receivedData = data
        let payloads = liveViewStream.attemptImageParse()
        XCTAssertNotNil(payloads)
        XCTAssertEqual(liveViewStream.receivedData.count, 151)
        XCTAssertEqual(liveViewStream.receivedData[0], 0)
        XCTAssertEqual(liveViewStream.receivedData[3], 0xcd)
        
        guard let image = payloads?.first?.image else {
            XCTFail("Didn't parse first payload as image correctly")
            return
        }
        
        XCTAssertEqual(image.size, CGSize(width: 640, height: 424))
    }
    
    func testRX100M7MultipleImageDataIsParsedCorrectly() {
        
        guard let hexString = try? String(contentsOf: Bundle(for: LiveViewStreamingTests.self).url(forResource: "liveview-rx100m7-multipleimages", withExtension: nil)!) else {
            XCTFail("Couldn't get hex string from file: liveview-rx100m7-multipleimages")
            return
        }
        
        let byteBuffer = ByteBuffer(hexString: hexString)
        let data = Data(bytes: byteBuffer.bytes.compactMap({ $0 }))
        let liveViewStream = LiveViewStream(camera: DummyCamera(), delegate: nil)
        liveViewStream.receivedData = data
        let payloads = liveViewStream.attemptImageParse()
        XCTAssertNotNil(payloads)
        XCTAssertEqual(payloads?.count, 2)
        XCTAssertEqual(liveViewStream.receivedData.count, 3115)
        XCTAssertEqual(liveViewStream.receivedData[0], 0)
        XCTAssertEqual(liveViewStream.receivedData[1], 0x3f)
        
        XCTAssertEqual(payloads?[0].image?.size, CGSize(width: 640, height: 424))
        XCTAssertEqual(payloads?[1].image?.size, CGSize(width: 640, height: 424))
    }
    
    func testA9iiMultipleImageDataIsParsedCorrectly() {
        
        guard let hexString = try? String(contentsOf: Bundle(for: LiveViewStreamingTests.self).url(forResource: "liveview-a9ii-multipleimages", withExtension: nil)!) else {
            XCTFail("Couldn't get hex string from file: liveview-a9ii-multipleimages")
            return
        }
        
        let byteBuffer = ByteBuffer(hexString: hexString)
        let data = Data(bytes: byteBuffer.bytes.compactMap({ $0 }))
        let liveViewStream = LiveViewStream(camera: DummyCamera(), delegate: nil)
        liveViewStream.receivedData = data
        
        let dataParts = [
            data[150..<24317],
            data[24469..<data.endIndex]
        ]
        
        outer: for i in 0..<24400 {
            if let image = UIImage(data: data[i..<24400]) {
                print("Partial image", image)
                break outer
            }
        }
        
        outer: for i in 24400..<49000 {
            if let image = UIImage(data: data[i..<data.endIndex]) {
                print("Partial image", image)
                break outer
            }
        }
        
        outer: for i in 48000..<data.endIndex {
            if let image = UIImage(data: data[i..<data.endIndex]) {
                print("Partial image", image)
                break outer
            }
        }
        
        print("Data", dataParts[1])
        
        data.enumerated().forEach({ (offset, element) in
            if element == 0xff, offset < data.count - 1, data[offset + 1] == 0xd8 {
                print("Start index", offset)
            }
            if element == 0x88, data[offset + 1] == 0x00, data[offset + 2] == 0x00 {
                print("End index", offset)
            }
        })
        
        var mungedData = Data()
        dataParts.forEach { (part) in
            mungedData.append(part)
        }
        
        guard let image = UIImage(data: mungedData) else {
            XCTFail("Failed to create image")
            return
        }

        print("Image", image)
        
//        let payloads = liveViewStream.attemptImageParse()
//        XCTAssertNotNil(payloads)
//        XCTAssertEqual(payloads?.count, 2)
//        XCTAssertEqual(liveViewStream.receivedData.count, 3115)
//        XCTAssertEqual(liveViewStream.receivedData[0], 0)
//        XCTAssertEqual(liveViewStream.receivedData[1], 0x3f)
//
//        XCTAssertEqual(payloads?[0].image?.size, CGSize(width: 640, height: 424))
//        XCTAssertEqual(payloads?[1].image?.size, CGSize(width: 640, height: 424))
    }
}
