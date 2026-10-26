import Darwin
import Flutter
import Network
import UIKit

public class XueHuaDeviceInfoPlugin: NSObject, FlutterPlugin {
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "xue_hua_device_info.network")
    private var currentPath: NWPath?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "xue_hua_device_info",
            binaryMessenger: registrar.messenger()
        )
        let instance = XueHuaDeviceInfoPlugin()
        instance.startNetworkMonitor()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    deinit {
        pathMonitor.cancel()
    }

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
        }
        pathMonitor.start(queue: monitorQueue)
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
        let device = UIDevice.current
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let machine = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(bitPattern: value))))
        }
        return [
            "deviceId": device.identifierForVendor?.uuidString,
            "manufacturer": "Apple",
            "model": machine.isEmpty ? device.model : machine,
            "serial": nil,
            "name": device.name,
        ]
    }

    private func getBatteryInfo() -> [String: Any?] {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = false }

        let level = device.batteryLevel
        let levelPercent: Double? = level < 0 ? nil : Double(level) * 100.0
        let isCharging: Bool?
        switch device.batteryState {
        case .charging, .full:
            isCharging = true
        case .unplugged:
            isCharging = false
        default:
            isCharging = nil
        }
        // UIDevice has no public battery-health API.
        return [
            "level": levelPercent,
            "isCharging": isCharging,
            "health": nil,
        ]
    }

    private func getNetworkInfo() -> [String: Any?] {
        let path = currentPath ?? pathMonitor.currentPath
        let networkType: String
        if path.status != .satisfied {
            networkType = "none"
        } else if path.usesInterfaceType(.wifi) {
            networkType = "wifi"
        } else if path.usesInterfaceType(.wiredEthernet) {
            networkType = "ethernet"
        } else if path.usesInterfaceType(.cellular) {
            networkType = "cellular"
        } else {
            networkType = "unknown"
        }
        return [
            "ipAddress": localIPv4(preferCellular: networkType == "cellular"),
            "networkType": networkType,
            "macAddress": nil,
        ]
    }

    /// Prefer en0 (Wi-Fi); for cellular prefer pdp_ip*. Skip loopback, RFC 3927
    /// link-local (169.254/16), and Clash-style fake-IP (198.18.0.0/15).
    private func localIPv4(preferCellular: Bool) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var bestEn0: String?
        var bestEn: String?
        var bestCellular: String?
        var bestOther: String?

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            guard let addr = current.pointee.ifa_addr else { continue }
            let family = addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name == "en0" || name.hasPrefix("en") || name.hasPrefix("pdp_ip") else {
                continue
            }

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
            guard !isUnusableIPv4(candidate) else { continue }

            if name == "en0" {
                bestEn0 = candidate
            } else if name.hasPrefix("en") {
                if bestEn == nil { bestEn = candidate }
            } else if name.hasPrefix("pdp_ip") {
                if bestCellular == nil { bestCellular = candidate }
            } else if bestOther == nil {
                bestOther = candidate
            }
        }

        if preferCellular {
            return bestCellular ?? bestEn0 ?? bestEn ?? bestOther
        }
        return bestEn0 ?? bestEn ?? bestCellular ?? bestOther
    }

    private func isUnusableIPv4(_ ip: String) -> Bool {
        if ip.hasPrefix("127.") { return true }
        if ip.hasPrefix("169.254.") { return true }
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4, parts[0] == 198, (parts[1] == 18 || parts[1] == 19) {
            return true
        }
        return false
    }

    private func getStorageInfo() -> [String: Any?] {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        let total = values?.volumeTotalCapacity ?? 0
        let free = Int(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        return [
            "totalBytes": total,
            "freeBytes": free,
            "storageType": "internal",
        ]
    }

    private func getDisplayInfo() -> [String: Any?] {
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        return [
            "width": Int(bounds.width * scale),
            "height": Int(bounds.height * scale),
            "scaleFactor": Double(scale),
            "refreshRate": Double(screen.maximumFramesPerSecond),
        ]
    }
}
