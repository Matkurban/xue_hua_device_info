# xue_hua_device_info

**English** | [简体中文](README.zh-CN.md)

Flutter plugin for device information: identity, battery, network, storage, and display.

Built with **MethodChannel** native implementations (Kotlin / Swift / C++). Web is not supported.

---

## Supported Platforms

| Platform | Support | Notes |
| -------- | ------- | ----- |
| Android  | Yes | Kotlin + MethodChannel |
| iOS      | Yes | Swift + SPM/CocoaPods |
| macOS    | Yes | Swift + SPM/CocoaPods |
| Windows  | Yes | C++ + MethodChannel |
| Linux    | Yes | C++ + MethodChannel |
| Web      | No | Not supported |

**Requirements:** Dart `^3.12.0`, Flutter `>=3.44.0`

---

## Installation

```yaml
dependencies:
  xue_hua_device_info: ^2.0.0
```

---

## Quick Start

```dart
import 'package:flutter/widgets.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final device = await XueHuaDeviceInfo.getDeviceInfo();
  final battery = await XueHuaDeviceInfo.getBatteryInfo();
  final network = await XueHuaDeviceInfo.getNetworkInfo();
  final storage = await XueHuaDeviceInfo.getStorageInfo();
  final display = await XueHuaDeviceInfo.getDisplayInfo();

  print(device.model);
  print(battery.level);
  print(network.ipAddress);
  print(storage.freeBytes);
  print('${display.width}x${display.height}');
}
```

No `initialize()` call is required.

---

## API

| Method | Returns |
| ------ | ------- |
| `getDeviceInfo()` | `DeviceInfo` |
| `getBatteryInfo()` | `BatteryInfo` |
| `getNetworkInfo()` | `NetworkInfo` |
| `getStorageInfo()` | `StorageInfo` |
| `getDisplayInfo()` | `DisplayInfo` |

### DeviceInfo

| Field | Type | Notes |
| ----- | ---- | ----- |
| `deviceId` | `String?` | Android ID / IDFV / machine UUID |
| `manufacturer` | `String?` | |
| `model` | `String?` | |
| `serial` | `String?` | Desktop when available; **always null on iOS/Android** (no public hardware serial on iOS) |
| `name` | `String?` | Device or host name. On **iOS 16+**, without the `com.apple.developer.device-information.user-assigned-device-name` entitlement this is typically a generic label (e.g. `"iPhone"`), not the user-assigned device name. |

### BatteryInfo

| Field | Type |
| ----- | ---- |
| `level` | `double?` (0–100) |
| `isCharging` | `bool?` |
| `health` | `String?` |

### NetworkInfo

| Field | Type | Notes |
| ----- | ---- | ----- |
| `ipAddress` | `String?` | |
| `networkType` | `String?` | `wifi` / `ethernet` / `cellular` / `none` / `unknown` |
| `macAddress` | `String?` | Desktop when available; `null` on mobile |

### StorageInfo

| Field | Type |
| ----- | ---- |
| `totalBytes` | `int` |
| `freeBytes` | `int` |
| `storageType` | `String?` |

### DisplayInfo

| Field | Type |
| ----- | ---- |
| `width` | `int` |
| `height` | `int` |
| `scaleFactor` | `double` |
| `refreshRate` | `double?` |

---

## Architecture

```
Dart XueHuaDeviceInfo
  → Platform Interface
    → MethodChannel ("xue_hua_device_info")
      → Android Kotlin / iOS Swift / macOS Swift / Windows C++ / Linux C++
```

iOS and macOS ship both **Swift Package Manager** and **CocoaPods** manifests per Flutter 3.44 plugin guidance.

---

## Breaking changes (2.0.0)

- Removed Rust / flutter_rust_bridge / Cargokit.
- Redesigned models and field names (`deviceId`, `name`, `totalBytes`, …).
- Removed `initialize()`.
- iOS no longer fabricates a Keychain UUID as `serial`.
