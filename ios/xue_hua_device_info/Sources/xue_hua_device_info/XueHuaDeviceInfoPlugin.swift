import Darwin
import Flutter
import Network
import UIKit

public class XueHuaDeviceInfoPlugin: NSObject, FlutterPlugin, XueHuaDeviceInfoHostApi {
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "xue_hua_device_info.network")
    private var currentPath: NWPath?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = XueHuaDeviceInfoPlugin()
        instance.startNetworkMonitor()
        registrar.publish(instance)
        XueHuaDeviceInfoHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: instance
        )
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        XueHuaDeviceInfoHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: nil
        )
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

    func getDeviceInfo() throws -> PigeonDeviceInfo {
        let device = UIDevice.current
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let machine = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(bitPattern: value))))
        }
        #if arch(arm64)
            let arch = "arm64"
        #elseif arch(x86_64)
            let arch = "x86_64"
        #else
            let arch = "unknown"
        #endif

        return PigeonDeviceInfo(
            deviceId: device.identifierForVendor?.uuidString,
            manufacturer: "Apple",
            model: machine.isEmpty ? device.model : machine,
            serial: nil,
            name: device.name,
            operatingSystem: "ios",
            osVersion: device.systemVersion,
            architecture: arch
        )
    }

    func getBatteryInfo() throws -> PigeonBatteryInfo {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = false }

        let level = device.batteryLevel
        let levelPercent: Double? = level < 0 ? nil : Double(level) * 100.0
        let isCharging: Bool?
        let chargingState: PigeonBatteryChargingState
        switch device.batteryState {
        case .charging:
            isCharging = true
            chargingState = .charging
        case .full:
            isCharging = true
            chargingState = .full
        case .unplugged:
            isCharging = false
            chargingState = .discharging
        case .unknown:
            isCharging = nil
            chargingState = .unknown
        @unknown default:
            isCharging = nil
            chargingState = .unknown
        }
        // UIDevice has no public battery-health API.
        return PigeonBatteryInfo(
            level: levelPercent,
            isCharging: isCharging,
            chargingState: chargingState,
            healthStatus: .unknown,
            health: nil,
            hasBattery: levelPercent != nil || isCharging != nil
        )
    }

    func getNetworkInfo() throws -> PigeonNetworkInfo {
        let path = currentPath ?? pathMonitor.currentPath
        let connectionType: PigeonNetworkConnectionType
        let networkType: String
        if path.status != .satisfied {
            connectionType = .none
            networkType = "none"
        } else if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
            networkType = "wifi"
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
            networkType = "ethernet"
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
            networkType = "cellular"
        } else {
            connectionType = .unknown
            networkType = "unknown"
        }
        let resolved = localIPv4(preferCellular: networkType == "cellular")
        return PigeonNetworkInfo(
            ipAddress: resolved?.ip,
            connectionType: connectionType,
            networkType: networkType,
            macAddress: nil,
            interfaceName: resolved?.interfaceName
        )
    }

    /// Prefer en0 (Wi-Fi); for cellular prefer pdp_ip*. Skip loopback, RFC 3927
    /// link-local (169.254/16), and Clash-style fake-IP (198.18.0.0/15).
    private func localIPv4(preferCellular: Bool) -> (ip: String, interfaceName: String)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var bestEn0: (String, String)?
        var bestEn: (String, String)?
        var bestCellular: (String, String)?
        var bestOther: (String, String)?

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
                bestEn0 = (candidate, name)
            } else if name.hasPrefix("en") {
                if bestEn == nil { bestEn = (candidate, name) }
            } else if name.hasPrefix("pdp_ip") {
                if bestCellular == nil { bestCellular = (candidate, name) }
            } else if bestOther == nil {
                bestOther = (candidate, name)
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

    func getStorageInfo() throws -> PigeonStorageInfo {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let free = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        return PigeonStorageInfo(
            totalBytes: total,
            freeBytes: free,
            mediumType: .internalStorage,
            storageType: "internal"
        )
    }

    func getDisplayInfo() throws -> PigeonDisplayInfo {
        let screen = UIScreen.main
        let bounds = screen.bounds
        let scale = screen.scale
        return PigeonDisplayInfo(
            width: Int64(bounds.width * scale),
            height: Int64(bounds.height * scale),
            scaleFactor: Double(scale),
            refreshRate: Double(screen.maximumFramesPerSecond)
        )
    }
}
