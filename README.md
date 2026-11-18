# xue_hua_device_info

**English** | [简体中文](README.zh-CN.md)

Flutter plugin for device information: identity, battery, network, storage, and display.

Built with **Pigeon (`^30.0.4`)** strongly-typed native host APIs across Kotlin, Swift, C++, and GObject. Web is not supported.

---

## Supported Platforms

| Platform | Support | Implementation                        |
| -------- | ------- | ------------------------------------- |
| Android  | Yes     | Kotlin + Pigeon HostApi               |
| iOS      | Yes     | Swift + Pigeon HostApi (SPM/CocoaPods)|
| macOS    | Yes     | Swift + Pigeon HostApi (SPM/CocoaPods)|
| Windows  | Yes     | C++ + Pigeon HostApi                  |
| Linux    | Yes     | C++/GObject + Pigeon HostApi          |
| Web      | No      | Not supported                         |

**Requirements:** Dart `^3.13.0`, Flutter `>=3.47.0`

---

## Installation

```yaml
dependencies:
  xue_hua_device_info: ^2.1.0
```

---

## Quick Start (Independent Subsystem Queries)

```dart
import 'package:flutter/widgets.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Each subsystem can be queried independently on demand:
  final device = await XueHuaDeviceInfo.getDeviceInfo();
  final battery = await XueHuaDeviceInfo.getBatteryInfo();
  final network = await XueHuaDeviceInfo.getNetworkInfo();
  final storage = await XueHuaDeviceInfo.getStorageInfo();
  final display = await XueHuaDeviceInfo.getDisplayInfo();

  debugPrint('${device.displayTitle} (${device.operatingSystem} ${device.architecture})');
  debugPrint('Battery: ${battery.formattedLevel}, state=${battery.chargingState.code}');
  debugPrint('Network: ${network.connectionType.code} (${network.ipAddress}) on ${network.interfaceName}');
  debugPrint('Storage: ${storage.usedGigabytes.toStringAsFixed(1)} / ${storage.totalGigabytes.toStringAsFixed(1)} GiB (${storage.mediumType.code})');
  debugPrint('Display: ${display.physicalResolution} (${display.logicalResolution} @ ${display.scaleFactor}x)');
}
```

---

## Redesigned Domain Models

### `DeviceInfo` (`lib/src/models/device_info.dart`)

| Property          | Type      | Description                                                                 |
| ----------------- | --------- | --------------------------------------------------------------------------- |
| `deviceId`        | `String?` | Android ID / IDFV / IOPlatformUUID / MachineGuid / DMI UUID or machine-id   |
| `manufacturer`    | `String?` | Hardware manufacturer                                                       |
| `model`           | `String?` | Hardware model / machine identifier                                         |
| `serial`          | `String?` | Hardware serial on desktop when readable; `null` on Android/iOS             |
| `name`            | `String?` | Host or user-visible device name                                            |
| `operatingSystem` | `String?` | `android`, `ios`, `macos`, `windows`, or `linux`                            |
| `osVersion`       | `String?` | Operating system release / build string                                     |
| `architecture`    | `String?` | CPU architecture (`arm64`, `x86_64`, etc.)                                  |
| `displayTitle`    | `String`  | Computed human-readable label combining `manufacturer` and `model`          |
| `hasSerial`       | `bool`    | Computed flag indicating whether `serial` is non-empty                      |

### `BatteryInfo` (`lib/src/models/battery_info.dart`)

| Property         | Type                   | Description                                                      |
| ---------------- | ---------------------- | ---------------------------------------------------------------- |
| `level`          | `double?`              | Charge percentage (`0.0`–`100.0`), or `null`                     |
| `levelRatio`     | `double?`              | Normalized charge ratio (`0.0`–`1.0`), or `null`                 |
| `formattedLevel` | `String`               | Formatted string (e.g. `"85.0%"` or `"N/A"`)                     |
| `isCharging`     | `bool?`                | Whether charging or full on external power                       |
| `chargingState`  | `BatteryChargingState` | `charging`, `discharging`, `full`, `notCharging`, `unknown`      |
| `healthStatus`   | `BatteryHealthStatus`  | `good`, `fair`, `poor`, `overheat`, `dead`, `overVoltage`, `cold`, `unknown` |
| `health`         | `String?`              | Raw platform health string when available                        |
| `hasBattery`     | `bool`                 | Whether a system battery is present                              |

### `NetworkInfo` (`lib/src/models/network_info.dart`)

| Property         | Type                    | Description                                                      |
| ---------------- | ----------------------- | ---------------------------------------------------------------- |
| `ipAddress`      | `String?`               | Active IPv4 address (skips loopback, link-local, and fake-IP)    |
| `connectionType` | `NetworkConnectionType` | `wifi`, `ethernet`, `cellular`, `vpn`, `loopback`, `none`, `unknown` |
| `networkType`    | `String`                | Canonical transport string (`wifi`, `ethernet`, `cellular`, `none`, `unknown`) |
| `macAddress`     | `String?`               | Hardware MAC address on desktop; `null` on mobile                |
| `interfaceName`  | `String?`               | Selected interface/adapter name (`en0`, `wlan0`, `eth0`, etc.)   |
| `isConnected`    | `bool`                  | Computed connectivity status                                     |
| `isWireless`     | `bool`                  | Computed wireless transport flag (`wifi` or `cellular`)          |

### `StorageInfo` (`lib/src/models/storage_info.dart`)

| Property         | Type                | Description                                                      |
| ---------------- | ------------------- | ---------------------------------------------------------------- |
| `totalBytes`     | `int`               | Total capacity in bytes                                          |
| `freeBytes`      | `int`               | Available capacity in bytes                                      |
| `usedBytes`      | `int`               | Computed used bytes (`totalBytes - freeBytes`)                   |
| `usageRatio`     | `double`            | Computed used ratio (`0.0`–`1.0`)                                |
| `usedPercentage` | `double`            | Computed used percentage (`0.0`–`100.0`)                         |
| `totalGigabytes` | `double`            | Total capacity in GiB                                            |
| `freeGigabytes`  | `double`            | Available capacity in GiB                                        |
| `usedGigabytes`  | `double`            | Used capacity in GiB                                             |
| `mediumType`     | `StorageMediumType` | `ssd`, `hdd`, `internal`, `nvme`, `virtual`, `unknown`           |
| `storageType`    | `String?`           | `internal` on mobile; `ssd` / `hdd` on desktop when detected     |

### `DisplayInfo` (`lib/src/models/display_info.dart`)

| Property             | Type      | Description                                                  |
| -------------------- | --------- | ------------------------------------------------------------ |
| `width`              | `int`     | Physical width in pixels                                     |
| `height`             | `int`     | Physical height in pixels                                    |
| `scaleFactor`        | `double`  | Logical-to-physical scale factor                             |
| `refreshRate`        | `double?` | Refresh rate in Hz when available                            |
| `logicalWidth`       | `double`  | Computed logical width in points                             |
| `logicalHeight`      | `double`  | Computed logical height in points                            |
| `aspectRatio`        | `double`  | Computed width-to-height ratio                               |
| `physicalResolution` | `String`  | Formatted physical resolution (`"${width}x$height"`)         |
| `logicalResolution`  | `String`  | Formatted logical resolution                                 |
| `isHighRefreshRate`  | `bool`    | Whether `refreshRate > 60.5` Hz                              |
