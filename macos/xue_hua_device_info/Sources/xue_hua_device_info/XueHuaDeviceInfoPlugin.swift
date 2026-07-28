import Cocoa
import CoreGraphics
import Darwin
import FlutterMacOS
import IOKit
import IOKit.network
import IOKit.ps
import SystemConfiguration

public class XueHuaDeviceInfoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "xue_hua_device_info",
            binaryMessenger: registrar.messenger
        )
        let instance = XueHuaDeviceInfoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDeviceInfo":
            result(getDeviceInfo())
        case "getBatteryInfo":
            result(getBatteryInfo())
        case "getNetworkInfo":
            result(getNetworkInfo())
        case "getStorageInfo":
            result(getStorageInfo())
        case "getDisplayInfo":
            result(getDisplayInfo())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getDeviceInfo() -> [String: Any?] {
        let platform = ioPlatformExpertProperties()
        return [
            "deviceId": platform["IOPlatformUUID"],
            "manufacturer": "Apple",
            "model": platform["model"] ?? sysctlString("hw.model"),
            "serial": platform["IOPlatformSerialNumber"],
            "name": Host.current().localizedName,
        ]
    }

    private func ioPlatformExpertProperties() -> [String: String] {
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }
        let service = IOServiceGetMatchingService(
            masterPort,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }

        var result: [String: String] = [:]
        if let uuid = IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            result["IOPlatformUUID"] = uuid
        }
        if let serial = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            result["IOPlatformSerialNumber"] = serial
        }
        if let modelData = IORegistryEntryCreateCFProperty(
            service,
            "model" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Data {
            let bytes = [UInt8](modelData)
            if let end = bytes.firstIndex(of: 0) {
                result["model"] = String(bytes: bytes[..<end], encoding: .utf8)
            } else {
                result["model"] = String(data: modelData, encoding: .utf8)
            }
        }
        return result
    }

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private func getBatteryInfo() -> [String: Any?] {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue()
              as? [String: Any]
        else {
            return [
                "level": nil,
                "isCharging": nil,
                "health": nil,
            ]
        }

        let capacity = description[kIOPSCurrentCapacityKey as String] as? Int
        let isCharging = description[kIOPSIsChargingKey as String] as? Bool
        return [
            "level": capacity.map { Double($0) },
            "isCharging": isCharging,
            "health": nil,
        ]
    }

    private func getNetworkInfo() -> [String: Any?] {
        return [
            "ipAddress": localIPv4(),
            "networkType": detectNetworkType(),
            "macAddress": primaryMacAddress(),
        ]
    }

    private func localIPv4() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            let candidate = String(cString: hostname)
            if !candidate.hasPrefix("127.") {
                address = candidate
                if name == "en0" {
                    break
                }
            }
        }
        return address
    }

    private func detectNetworkType() -> String {
        guard let store = SCDynamicStoreCreate(nil, "xue_hua_device_info" as CFString, nil, nil),
              let global =
              SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)
                  as? [String: Any],
                  let primary = global["PrimaryInterface"] as? String
        else {
            return localIPv4() == nil ? "none" : "unknown"
        }

        if primary.hasPrefix("bridge") || primary.hasPrefix("eth") {
            return "ethernet"
        }
        if primary.hasPrefix("en") {
            return interfaceIsBuiltInEthernet(primary) ? "ethernet" : "wifi"
        }
        return "unknown"
    }

    /// Prefer IOKit media type; fall back to common Thunderbolt/USB ethernet naming.
    private func interfaceIsBuiltInEthernet(_ bsdName: String) -> Bool {
        if bsdName.hasPrefix("en") {
            // en0 is almost always Wi-Fi on modern Macs; higher en* may be USB/Thunderbolt ethernet.
            if bsdName != "en0", let media = ioNetworkMediaType(forBSDName: bsdName) {
                if media.localizedCaseInsensitiveContains("Ethernet") {
                    return true
                }
                if media.localizedCaseInsensitiveContains("IEEE80211")
                    || media.localizedCaseInsensitiveContains("AirPort")
                {
                    return false
                }
            }
        }
        return false
    }

    private func ioNetworkMediaType(forBSDName bsdName: String) -> String? {
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }
        guard let matching = IOBSDNameMatching(masterPort, 0, bsdName) else {
            return nil
        }
        let service = IOServiceGetMatchingService(masterPort, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var parent: io_service_t = 0
        let kr = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent)
        guard kr == KERN_SUCCESS, parent != 0 else { return nil }
        defer { IOObjectRelease(parent) }

        if let type = IORegistryEntryCreateCFProperty(
            parent,
            "IOName" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return type
        }
        if let type = IORegistryEntryCreateCFProperty(
            parent,
            "CFBundleIdentifier" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return type
        }
        return nil
    }

    private func primaryMacAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let name = String(cString: current.pointee.ifa_name)
            guard name == "en0", let addr = current.pointee.ifa_addr else { continue }
            guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let sdl = UnsafeRawPointer(addr).bindMemory(to: sockaddr_dl.self, capacity: 1)
            let nlen = Int(sdl.pointee.sdl_nlen)
            let alen = Int(sdl.pointee.sdl_alen)
            guard alen == 6 else { continue }

            let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_data) ?? 8
            let macPtr = UnsafeRawPointer(sdl).advanced(by: dataOffset + nlen).assumingMemoryBound(to: UInt8.self)
            let bytes = UnsafeBufferPointer(start: macPtr, count: 6)
            return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
        }
        return nil
    }

    private func getStorageInfo() -> [String: Any?] {
        let url = URL(fileURLWithPath: "/")
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        let total = values?.volumeTotalCapacity ?? 0
        let free = Int(values?.volumeAvailableCapacityForImportantUsage ?? Int64(values?.volumeAvailableCapacity ?? 0))
        return [
            "totalBytes": total,
            "freeBytes": free,
            "storageType": nil,
        ]
    }

    private func getDisplayInfo() -> [String: Any?] {
        let displayId = CGMainDisplayID()
        let width = CGDisplayPixelsWide(displayId)
        let height = CGDisplayPixelsHigh(displayId)
        let mode = CGDisplayCopyDisplayMode(displayId)
        let refresh = mode?.refreshRate
        let scale: Double
        if let screen = NSScreen.main {
            scale = screen.backingScaleFactor
        } else {
            scale = 1.0
        }
        return [
            "width": width,
            "height": height,
            "scaleFactor": scale,
            "refreshRate": (refresh != nil && refresh! > 0) ? refresh : nil,
        ]
    }
}
