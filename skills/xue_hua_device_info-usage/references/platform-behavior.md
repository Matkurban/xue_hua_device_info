# Platform field behavior (v2.1.0)

Values below come from the current native plugins (`android/`, `ios/`, `macos/`, `windows/`, `linux/`) mapped through Pigeon (`^30.0.4`) `Wire*` wire messages into the Dart domain models. Do not invent extra fields. A Dart `null` means the host left the optional wire field unset (`null` / empty string sanitized to `null`).

Web is not supported. On non-Android/non-Apple platforms without a native registrar (or Web), `XueHuaDeviceInfo` falls back to Pigeon's `BasicMessageChannel`, which throws `MissingPluginException`.

`networkType` / `NetworkConnectionType` values emitted natively: `wifi`, `ethernet`, `cellular`, `vpn`, `loopback`, `none`, `unknown`.

---

## `DeviceInfo`

| Field | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| `deviceId` | `Settings.Secure.ANDROID_ID` | `UIDevice.identifierForVendor?.uuidString` (may be `null`) | `IOPlatformUUID` | `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` | `/sys/class/dmi/id/product_uuid`, else `/etc/machine-id`, else `/var/lib/dbus/machine-id` |
| `manufacturer` | `Build.MANUFACTURER` | Always `"Apple"` | Always `"Apple"` | BIOS `SystemManufacturer` (sanitized) | `/sys/class/dmi/id/sys_vendor` (sanitized) |
| `model` | `Build.MODEL` | `uname` `machine` (e.g. `iPhone15,2`), else `UIDevice.model` | IOKit `model` bytes, else `sysctl hw.model` | BIOS `SystemProductName` (sanitized) | `/sys/class/dmi/id/product_name` |
| `serial` | **Always `null`** | **Always `null`** | `IOPlatformSerialNumber` when readable | BIOS `SystemSerialNumber` (sanitized) | `/sys/class/dmi/id/product_serial` |
| `name` | API 25+: `Settings.Global.DEVICE_NAME`, else `Build.MODEL` | `UIDevice.name` | `Host.current().localizedName` | `GetComputerNameW` | `gethostname` (NUL-terminated) |
| `operatingSystem` | `"android"` | `"ios"` | `"macos"` | `"windows"` | `"linux"` |
| `osVersion` | `Build.VERSION.RELEASE` | `ProcessInfo.operatingSystemVersionString` | `ProcessInfo.operatingSystemVersionString` | Registry `CurrentBuildNumber` / `UBR` / `CurrentVersion` | `utsname.release` |
| `architecture` | `Build.SUPPORTED_ABIS.firstOrNull` | `uname` `machine` (`arm64` / `x86_64`) | `uname` `machine` (`arm64` / `x86_64`) | `SYSTEM_INFO.wProcessorArchitecture` | `utsname.machine` |

Windows and Linux hardware string sanitization drops placeholders such as `None`, `Default string`, `To be filled by O.E.M.`, `System Serial Number`, `O.E.M.`, `OEM`, `System Product Name`, and `System Manufacturer`.

---

## `BatteryInfo`

| Field | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| `level` | `BATTERY_PROPERTY_CAPACITY` in `0`–`100`, else `null` | `UIDevice.batteryLevel * 100` when monitoring enabled (`>= 0`), else `null` | Present `InternalBattery` `Current Capacity / Max Capacity * 100`, else `null` | `BatteryLifePercent` unless `255` (unknown) or `BatteryFlag == 128` | First `type=Battery` sysfs `capacity` (`0`–`100`), else `null` |
| `isCharging` | `status == CHARGING \|\| status == FULL` | `true` for `.charging`/`.full`; `false` for `.unplugged`; `null` otherwise | `kIOPSIsCharging` when source exists, else `null` | `(BatteryFlag & 8) != 0` unless `BatteryFlag == 255` (`null`) or `128` (`null`) | `true` if sysfs `status` is `Charging` or `Full`; `null` if no battery found |
| `chargingState` | `charging`, `discharging`, `full`, `notCharging`, `unknown` | `charging`, `discharging`, `full`, `unknown` | `charging`, `full`, `notCharging`, `discharging`, `unknown` | `charging`, `full` (`ACLineStatus == 1 && 100%`), `notCharging` (`ACLineStatus == 1`), `discharging`, or `unknown` (`BatteryFlag == 255` / `128`) | Mapped from sysfs `status` (`Charging`, `Discharging`, `Full`, `Not charging`), else `unknown` |
| `health` / `healthStatus` | Mapped (`good`, `fair` absent, `overheat`, `dead`, `over_voltage`, `unspecified_failure`, `cold`, `unknown`) | **Always `null` / `unknown`** | `kIOPSBatteryHealthKey` (`Good`/`Fair`/`Poor`), else `null` / `unknown` | **Always `null` / `unknown`** | sysfs `health` (`Good`, `Overheat`, `Dead`, `Over voltage`, `Cold`) mapped + raw label |
| `hasBattery` | Present extra + valid capacity/intent | `batteryState != .unknown` or `level != null` | Present `InternalBattery` source found | `false` when `BatteryFlag == 128` or (`BatteryFlag == 255 && BatteryLifePercent == 255`); else `true` | Usable sysfs battery entry found |

---

## `NetworkInfo`

| Field | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| `ipAddress` | Active `LinkProperties` IPv4 (site-local preferred); skips `127.*`, `169.254.*`, `198.18.0.0/15`; else filtered `NetworkInterface` scan | Selected `en0` / `en*` / `pdp_ip*` IPv4 (skips `127.*`, `169.254.*`, `198.18.0.0/15`) | Selected iface IPv4 (`127.*`, `169.254.*`, `198.18.0.0/15` skipped) | Selected adapter IPv4 (`127.*`, `169.254.*`, `198.18.0.0/15` skipped) | Selected iface IPv4 (`127.*`, `169.254.*`, `198.18.0.0/15` skipped) |
| `connectionType` / `networkType` | `wifi`, `ethernet`, `cellular`, `vpn`, `none`, `unknown` | `NWPathMonitor` synchronized path (`wifi`, `ethernet`, `cellular`, `none`, `unknown`) | `SCNetworkInterfaceGetInterfaceType` / name (`wifi`, `ethernet`, `none`, `unknown`) | `GetBestInterfaceEx` + `ClassifyAdapter` (`wifi`, `ethernet`, `none`, `unknown`) | `/proc/net/route` + sysfs (`wifi`, `ethernet`, `none`, `unknown`) |
| `macAddress` | **Always `null`** | **Always `null`** | MAC of selected iface (`xx:xx:...`) | MAC of selected adapter (`xx:xx:...`) | MAC of selected iface |
| `interfaceName` | `LinkProperties.interfaceName` (or selected interface name) | BSD iface (`en0`, `pdp_ip0`, ...) | BSD iface (`en0`, ...) | Adapter friendly/description name | Interface name (`wlan0`, `eth0`, ...) |

---

## `StorageInfo`

| Field | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| `totalBytes` / `freeBytes` | `StatFs` of `Environment.getDataDirectory()` | `NSHomeDirectory()` volume total / available important capacity | `/` volume total / important-usage capacity | `GetDiskFreeSpaceExW` on Windows-dir volume | `statvfs("/")` (`f_blocks * f_frsize` / `f_bavail * f_frsize`) |
| `mediumType` / `storageType` | `StorageMediumType.internal` (`"internal"`) | `StorageMediumType.internal` (`"internal"`) | IOKit `Medium Type` (`ssd` / `hdd` / `unknown`) | `IOCTL_STORAGE_QUERY_PROPERTY` seek penalty (`ssd` / `hdd` / `unknown`) | sysfs `queue/rotational` (`ssd` / `hdd` / `unknown`) |

---

## `DisplayInfo`

| Field | Android | iOS | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| `width` / `height` | `Display.getMode().physicalWidth/Height` (API 23+), fallback `DisplayMetrics` | Active `UIWindowScene.screen` (fallback `UIScreen.main`) `bounds * scale` | `CGMainDisplayID()` `CGDisplayMode` pixelWidth/Height (Retina physical) | `SM_CXSCREEN` / `SM_CYSCREEN` | GDK primary (or first) monitor geometry × `gdk_monitor_get_scale_factor` |
| `scaleFactor` | `DisplayMetrics.density` | Screen `scale` | Matching `NSScreen` (`NSScreenNumber == CGMainDisplayID()`) `backingScaleFactor`, else `1.0` | `LOGPIXELSX / 96.0` | GDK `gdk_monitor_get_scale_factor`, else `1.0` |
| `refreshRate` | Active `Display.Mode.refreshRate`, else `Display.refreshRate` | Screen `maximumFramesPerSecond` | `CGDisplayMode.refreshRate` (`> 0`), else matching `NSScreen.maximumFramesPerSecond` | `EnumDisplaySettingsW` `dmDisplayFrequency` (`> 1`), else `null` | `gdk_monitor_get_refresh_rate` / `1000.0` (`> 0`), else `null` |

---

## Transport & Errors

- **Android:** Pigeon JNI Native Interop (`XueHuaDeviceInfoHostApiRegistrar` + `messages.g.jni.dart`).
- **iOS & macOS:** Pigeon Swift FFI Native Interop (`XueHuaDeviceInfoHostApiSetup` + `messages.g.ffi.dart`).
- **Windows & Linux:** Pigeon typed `BasicMessageChannel` endpoints under `dev.flutter.pigeon.xue_hua_device_info.XueHuaDeviceInfoHostApi.{getDeviceInfo,getBatteryInfo,getNetworkInfo,getStorageInfo,getDisplayInfo}`.
- Always ensure `WidgetsFlutterBinding.ensureInitialized()` has run before calling any method.
