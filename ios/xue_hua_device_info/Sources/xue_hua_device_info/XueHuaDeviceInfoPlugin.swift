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
            "ipAddress": localIPv4(),
            "networkType": networkType,
            "macAddress": nil,
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
            let family = addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }
            let name = String(cString: current.pointee.ifa_name)
            guard name == "en0" || name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }

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
