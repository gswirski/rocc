//
//  DeviceDiscovery.swift
//  Rocc
//
//  Created by Simon Mitchell on 20/04/2018.
//  Copyright © 2018 Simon Mitchell. All rights reserved.
//

import Foundation

import SystemConfiguration
import os

/// A protocol for providing discovery messages to the shared camera discoverer.
///
/// This mirrors CameraDiscovererDelegate, but is only used internally for individual implementations of `DeviceDiscover`
protocol DeviceDiscovererDelegate {
    
    /// Called if the DeviceDiscoverer error for any reason. The error will be as descriptive as possible.
    ///
    /// - Parameters:
    ///   - discoverer: The discoverer object that errored.
    ///   - error: The error that occured.
    func deviceDiscoverer<T: DeviceDiscoverer>(_ discoverer: T, didError error: Error)
    
    /// Called when a camera device is discovered
    ///
    /// - Parameters:
    ///   - discoverer: The discoverer object that discovered a device.
    ///   - discovered: The device that it discovered.
    ///   - isCached: Whether the device was loaded from a cached xml discovery file.
    func deviceDiscoverer<T: DeviceDiscoverer>(_ discoverer: T, discovered device: Camera, isCached: Bool)

    func deviceDiscoverer<T: DeviceDiscoverer>(_ discoverer: T, didDetectNetworkChange ssid: String?)

}

/// A protocol to be implemented by device discovery implementations
protocol DeviceDiscoverer {
    
    /// The delegate which can be called to provide discovery information
    var delegate: DeviceDiscovererDelegate? { get set }
    
    init(delegate: DeviceDiscovererDelegate)
    
    /// Function which can be called to start the discoverer
    func start()
    
    /// Function which can be called to stop the discoverer
    ///
    /// - Parameter callback: A callback function which MUST be called
    /// once the discoverer has stopped
    func stop(_ callback: @escaping () -> Void)
    
    /// Whether the discoverer is currently searching
    var isSearching: Bool { get }
}

public enum CameraDiscoveryError: Error {
    case unknown
}

/// A protocol for receiving messages about camera discovery
public protocol CameraDiscovererDelegate {
    
    /// Called if the DeviceDiscoverer errored for any reason. The error will be as descriptive as possible.
    ///
    /// - Parameters:
    ///   - discoverer: The discoverer object that errored.
    ///   - error: The error that occured.
    func cameraDiscoverer(_ discoverer: CameraDiscoverer, didError error: Error)
    
    /// Called when a camera device is discovered
    ///
    /// - Note: if `isCached == true` you should be cautious auto-connecting to the camera (Especially if it's a transfer device) as cameras in transfer mode can advertise multiple connectivity methods and the correct one may not be returned until it's passed to you with `isCached == false`.
    ///
    /// - Parameters:
    ///   - discoverer: The discoverer object that discovered a device.
    ///   - discovered: The device that it discovered.
    ///   - isCached: Whether the camera was loaded from a cached xml file url.
    func cameraDiscoverer(_ discoverer: CameraDiscoverer, discovered device: Camera, isCached: Bool)

    func cameraDiscoverer(_ discoverer: CameraDiscoverer, didDetectNetworkChange ssid: String?)
}

/// A class which enables the discovery of cameras
public final class CameraDiscoverer {
    
    private let discoverer: DeviceDiscoveryHandle
    
    private let reachability: Reachability?


    /// A delegate which will have methods called on it when cameras are discovered or an error occurs.
    public var delegate: CameraDiscovererDelegate?
    
    private var discoveredCameras: [(camera: Camera, isCached: Bool)] = []
    
    /// A map of cameras by the SSID the local device was connected to when they were discovered
    public var camerasBySSID: [String?: [(camera: Camera, isCached: Bool)]] = [:]
    
    var queue = DispatchQueue(label: "CameraDiscoverer")

    /// Creates a new discoverer
    public init() {
        reachability = Reachability(hostName: "www.google.co.uk")

        discoverer = DeviceDiscoveryHandle()
        discoverer.observer = self
    }
    
    /// Starts the camera discoverer listening for cameras
    public func start() {
        discoverer.start()
        reachability?.start(callback: { [weak self] (flags) in
            self?.discoverer.poke()
        })
    }
    
    /// Stops the camera discoverer from listening for cameras
    ///
    /// - Parameter callback: A closure called when all discovery has been stopped
    public func stop(with callback: @escaping () -> Void) {
        reachability?.stop()
        discoverer.stop()
    }
}

extension CameraDiscoverer: DeviceDiscovererObserver {
    func deviceDiscoverer(discoveredDevice: ShutterDeviceHandle) {
        if let url = URL(string: "http://\(discoveredDevice.host)"), let camera = CanonPTPIPDevice(dictionary: ["manufacturer": "Canon", "friendlyName": discoveredDevice.name]) {
            camera.baseURL = url
            print("PTP/IP Connection URL \(url) \(url.host)")
            delegate?.cameraDiscoverer(self, discovered: camera, isCached: false)
        }
    }
}