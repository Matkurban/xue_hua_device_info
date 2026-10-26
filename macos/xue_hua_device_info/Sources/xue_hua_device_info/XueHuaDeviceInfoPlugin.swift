import Cocoa
import CoreGraphics
import Darwin
import DiskArbitration
import FlutterMacOS
import IOKit
import IOKit.network
import IOKit.ps
import IOKit.storage
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

    // MARK: - Device

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

    // MARK: - Battery

    /// Prefer an internal battery that is present (IOPSKeys.h).
    private func getBatteryInfo() -> [String: Any?] {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return emptyBattery()
        }

        var chosen: [String: Any]?
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any]
            else { continue }
            let present = description[kIOPSIsPresentKey as String] as? Bool ?? true
            guard present else { continue }
            let type = description[kIOPSTypeKey as String] as? String
            if type == kIOPSInternalBatteryType {
                chosen = description
                break
            }
            if chosen == nil {
                chosen = description
            }
        }

        guard let description = chosen else { return emptyBattery() }

        let current = description[kIOPSCurrentCapacityKey as String] as? Int
        let maxCap = description[kIOPSMaxCapacityKey as String] as? Int
        let level: Double?
        if let current, let maxCap, maxCap > 0 {
            // Apple-defined sources publish percent units (IOPSKeys.h); still normalize.
            let pct = (Double(current) / Double(maxCap)) * 100.0
            level = min(100.0, max(0.0, pct))
        } else if let current {
            level = Double(current)
        } else {
            level = nil
        }

        let isCharging = description[kIOPSIsChargingKey as String] as? Bool
        // kIOPSBatteryHealthKey → "Good" / "Fair" / "Poor" when published.
        let health = description[kIOPSBatteryHealthKey as String] as? String

        return [
            "level": level,
            "isCharging": isCharging,
            "health": health,
        ]
    }

    private func emptyBattery() -> [String: Any?] {
        [
            "level": nil,
            "isCharging": nil,
            "health": nil,
        ]
    }

    // MARK: - Network

    private func getNetworkInfo() -> [String: Any?] {
        let iface = selectNetworkInterface()
        guard let iface else {
            return [
                "ipAddress": nil,
                "networkType": "none",
                "macAddress": nil,
            ]
        }
        return [
            "ipAddress": ipv4(on: iface),
            "networkType": networkType(forBSDName: iface),
            "macAddress": macAddress(on: iface),
        ]
    }

    /// Pick one BSD interface: prefer SCDynamicStore PrimaryInterface when it has a
    /// usable IPv4; otherwise the best physical `en*` / `eth*` with a real address.
    /// Skips RFC 3927 link-local and Clash Meta fake-IP (198.18.0.0/15).
    private func selectNetworkInterface() -> String? {
        if let primary = primaryIPv4Interface(),
           !isVirtualInterface(primary),
           ipv4(on: primary) != nil
        {
            return primary
        }

        var candidates: [(name: String, score: Int)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var seen = Set<String>()
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let name = String(cString: current.pointee.ifa_name)
            guard !seen.contains(name) else { continue }
            seen.insert(name)
            guard !isVirtualInterface(name) else { continue }
            guard ipv4(on: name) != nil else { continue }
            var score = 10
            if name == "en0" { score += 50 }
            if name.hasPrefix("en") || name.hasPrefix("eth") { score += 20 }
            candidates.append((name, score))
        }
        return candidates.max(by: { $0.score < $1.score })?.name
    }

    private func primaryIPv4Interface() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "xue_hua_device_info" as CFString, nil, nil),
              let global =
              SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)
                  as? [String: Any],
              let primary = global["PrimaryInterface"] as? String
        else {
            return nil
        }
        return primary
    }

    private func isVirtualInterface(_ name: String) -> Bool {
        let prefixes = ["lo", "utun", "ipsec", "ppp", "awdl", "llw", "bridge", "vmenet", "ap", "anpi", "gif", "stf", "tun", "tap", "vmnet"]
        // Exact loopback; prefix match for virtual families. Do not treat "en*" as virtual.
        if name == "lo0" || name == "lo" { return true }
        for p in prefixes where p != "lo" {
            if name.hasPrefix(p) { return true }
        }
        return false
    }

    private func isUnusableIPv4(_ ip: String) -> Bool {
        if ip.hasPrefix("127.") { return true }
        if ip.hasPrefix("169.254.") { return true } // RFC 3927 link-local
        // Clash Meta / similar fake-IP pool: 198.18.0.0/15
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4, parts[0] == 198, (parts[1] == 18 || parts[1] == 19) {
            return true
        }
        return false
    }

    private func ipv4(on bsdName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            guard String(cString: current.pointee.ifa_name) == bsdName,
                  let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET)
            else { continue }

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
            if !isUnusableIPv4(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func macAddress(on bsdName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            guard String(cString: current.pointee.ifa_name) == bsdName,
                  let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK)
            else { continue }

            let sdl = UnsafeRawPointer(addr).bindMemory(to: sockaddr_dl.self, capacity: 1)
            let nlen = Int(sdl.pointee.sdl_nlen)
            let alen = Int(sdl.pointee.sdl_alen)
            guard alen == 6 else { continue }

            let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \sockaddr_dl.sdl_data) ?? 8
            let macPtr = UnsafeRawPointer(sdl).advanced(by: dataOffset + nlen)
                .assumingMemoryBound(to: UInt8.self)
            let bytes = UnsafeBufferPointer(start: macPtr, count: 6)
            return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
        }
        return nil
    }

    /// Prefer SCNetworkInterfaceGetInterfaceType (SystemConfiguration); fall back to BSD name heuristics.
    private func networkType(forBSDName bsdName: String) -> String {
        if let type = scInterfaceType(forBSDName: bsdName) {
            if type == kSCNetworkInterfaceTypeIEEE80211 as String {
                return "wifi"
            }
            if type == kSCNetworkInterfaceTypeEthernet as String
                || type == kSCNetworkInterfaceTypeBond as String
                || type == kSCNetworkInterfaceTypeVLAN as String
            {
                return "ethernet"
            }
            if type == kSCNetworkInterfaceTypeWWAN as String {
                return "cellular"
            }
        }

        if bsdName.hasPrefix("bridge") || bsdName.hasPrefix("eth") {
            return "ethernet"
        }
        if bsdName.hasPrefix("en") {
            return interfaceIsBuiltInEthernet(bsdName) ? "ethernet" : "wifi"
        }
        return "unknown"
    }

    private func scInterfaceType(forBSDName bsdName: String) -> String? {
        guard let all = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return nil
        }
        for iface in all {
            if let name = SCNetworkInterfaceGetBSDName(iface) as String?, name == bsdName {
                return SCNetworkInterfaceGetInterfaceType(iface) as String?
            }
        }
        return nil
    }

    /// Prefer IOKit media type; fall back to common Thunderbolt/USB ethernet naming.
    private func interfaceIsBuiltInEthernet(_ bsdName: String) -> Bool {
        if bsdName.hasPrefix("en") {
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

    // MARK: - Storage

    private func getStorageInfo() -> [String: Any?] {
        let url = URL(fileURLWithPath: "/")
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
        let total = values?.volumeTotalCapacity ?? 0
        let free = Int(
            values?.volumeAvailableCapacityForImportantUsage
                ?? Int64(values?.volumeAvailableCapacity ?? 0)
        )
        return [
            "totalBytes": total,
            "freeBytes": free,
            "storageType": detectStorageType(),
        ]
    }

    /// IOKit Device Characteristics `Medium Type` via DiskArbitration → IOMedia
    /// (kIOPropertyMediumTypeSolidStateKey / RotationalKey).
    private func detectStorageType() -> String? {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return nil }
        let path = URL(fileURLWithPath: "/") as CFURL
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, path) else {
            return nil
        }
        let media = DADiskCopyIOMedia(disk)
        guard media != 0 else { return nil }
        defer { IOObjectRelease(media) }

        guard let chars = IORegistryEntrySearchCFProperty(
            media,
            kIOServicePlane,
            kIOPropertyDeviceCharacteristicsKey as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        ) as? [String: Any]
        else {
            return nil
        }

        guard let medium = chars[kIOPropertyMediumTypeKey] as? String else { return nil }
        if medium == kIOPropertyMediumTypeSolidStateKey {
            return "ssd"
        }
        if medium == kIOPropertyMediumTypeRotationalKey {
            return "hdd"
        }
        return nil
    }

    // MARK: - Display

    private func getDisplayInfo() -> [String: Any?] {
        let displayId = CGMainDisplayID()
        let mode = CGDisplayCopyDisplayMode(displayId)

        // Prefer CGDisplayMode pixel dimensions (physical Retina pixels).
        // CGDisplayPixelsWide/High can report the point size on HiDPI.
        let width: Int
        let height: Int
        if let mode, mode.pixelWidth > 0, mode.pixelHeight > 0 {
            width = Int(mode.pixelWidth)
            height = Int(mode.pixelHeight)
        } else {
            width = CGDisplayPixelsWide(displayId)
            height = CGDisplayPixelsHigh(displayId)
        }

        var refresh: Double? = nil
        if let mode {
            let rate = mode.refreshRate
            if rate > 0 {
                refresh = rate
            }
        }
        // Built-in panels sometimes report 0 from CG; NSScreen.maximumFramesPerSecond is reliable (macOS 12+).
        if refresh == nil {
            if #available(macOS 12.0, *), let screen = NSScreen.main {
                let fps = screen.maximumFramesPerSecond
                if fps > 0 {
                    refresh = Double(fps)
                }
            }
        }

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
            "refreshRate": refresh,
        ]
    }
}
