//
//  File.swift
//  Rust PTP
//
//  Created by Grzegorz Świrski on 31/05/2021.
//

import Foundation


final class WeakHolder<T: AnyObject> {
    weak var object: T?

    init(_ object: T) {
        self.object = object
    }
}

extension RustByteSlice {
    func asUnsafeBufferPointer() -> UnsafeBufferPointer<UInt8> {
        return UnsafeBufferPointer(start: bytes, count: len)
    }

    func asString(encoding: String.Encoding = .utf8) -> String? {
        return String(bytes: asUnsafeBufferPointer(), encoding: encoding)
    }
}

final class ShutterDeviceHandle {
    private let raw: OpaquePointer
    
    init(_ raw: OpaquePointer) {
        self.raw = raw
    }
    
    deinit {
        shutter_device_release(raw)
    }
    
    var name: String {
        return shutter_device_name(raw).asString()!
    }
    
    var host: String {
        return shutter_device_host(raw).asString()!
    }
}

protocol DeviceDiscovererObserver: AnyObject {
    func deviceDiscoverer(discoveredDevice: ShutterDeviceHandle)
}

final class DeviceDiscoveryHandle {
    private var raw: OpaquePointer!

    weak var observer: DeviceDiscovererObserver?

    init() {
        raw = shutter_discovery_new()
    }
    
    func start() {
        let weakSelf = UnsafeMutableRawPointer(Unmanaged.passRetained(WeakHolder(self)).toOpaque())
        let observer = device_discovery_observer(user: weakSelf, destroy_user: freeDeviceDiscoveryHandle, discovered_device: handleDiscoveredDevice)

        shutter_discovery_start(raw, observer)
    }

    func stop() {
        shutter_discovery_stop(raw)
    }
    
    deinit {
        shutter_discovery_release(raw)
    }
}

private func freeDeviceDiscoveryHandle(ptr: UnsafeMutableRawPointer?) {
    let _ = Unmanaged<WeakHolder<DeviceDiscoveryHandle>>.fromOpaque(ptr!).takeRetainedValue()
}

private func handleDiscoveredDevice(ptr: UnsafeMutableRawPointer?, device: OpaquePointer?) {
    autoreleasepool {
        let handle = Unmanaged<WeakHolder<DeviceDiscoveryHandle>>.fromOpaque(ptr!).takeUnretainedValue()
        DispatchQueue.main.async {
            guard let handle = handle.object else { return }
            handle.observer?.deviceDiscoverer(discoveredDevice: ShutterDeviceHandle(device!))
        }
    }
}
