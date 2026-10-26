# xue_hua_device_info

**English** | [简体中文](README.zh-CN.md)

Flutter plugin for device information: identity, battery, network, storage, and display.

Built with **MethodChannel** native implementations (Kotlin / Swift / C++). Web is not supported.

---

## Supported Platforms

| Platform | Support | Notes                  |
| -------- | ------- | ---------------------- |
| Android  | Yes     | Kotlin + MethodChannel |
| iOS      | Yes     | Swift + SPM/CocoaPods  |
| macOS    | Yes     | Swift + SPM/CocoaPods  |
| Windows  | Yes     | C++ + MethodChannel    |
| Linux    | Yes     | C++ + MethodChannel    |
| Web      | No      | Not supported          |

**Requirements:** Dart `^3.12.0`, Flutter `>=3.44.0`

---

## Installation

```yaml
dependencies:
  xue_hua_device_info: ^2.0.9
```

---

## Package skills

This package ships an AI agent skill that documents every public class and method.

After adding the dependency, install it in your app project:

```bash
dart run skills@ get
```

That copies `xue_hua_device_info-usage` into your agent skills directory (for example `.agents/skills/`). The skill covers `XueHuaDeviceInfo` usage, model fields, `PlatformException` handling, and per-platform nullability.

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

| Method             | Returns       |
| ------------------ | ------------- |
| `getDeviceInfo()`  | `DeviceInfo`  |
| `getBatteryInfo()` | `BatteryInfo` |
| `getNetworkInfo()` | `NetworkInfo` |
| `getStorageInfo()` | `StorageInfo` |
| `getDisplayInfo()` | `DisplayInfo` |

### DeviceInfo

| Field          | Type      | Notes                                                                                                                                                                                                                   |
| -------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `deviceId`     | `String?` | Android ID / IDFV / machine UUID                                                                                                                                                                                        |
| `manufacturer` | `String?` |                                                                                                                                                                                                                         |
| `model`        | `String?` |                                                                                                                                                                                                                         |
| `serial`       | `String?` | Desktop when available; **always null on iOS/Android** (no public hardware serial on iOS)                                                                                                                               |
| `name`         | `String?` | Device or host name. On **iOS 16+**, without the `com.apple.developer.device-information.user-assigned-device-name` entitlement this is typically a generic label (e.g. `"iPhone"`), not the user-assigned device name. |

### BatteryInfo

| Field        | Type              |
| ------------ | ----------------- |
| `level`      | `double?` (0–100) |
| `isCharging` | `bool?`           |
| `health`     | `String?`         |

### NetworkInfo

| Field         | Type      | Notes                                                 |
| ------------- | --------- | ----------------------------------------------------- |
| `ipAddress`   | `String?` |                                                       |
| `networkType` | `String?` | `wifi` / `ethernet` / `cellular` / `none` / `unknown` |
| `macAddress`  | `String?` | Desktop when available; `null` on mobile              |

### StorageInfo

| Field         | Type      |
| ------------- | --------- |
| `totalBytes`  | `int`     |
| `freeBytes`   | `int`     |
| `storageType` | `String?` | Android/iOS: `internal`. Linux/Windows/macOS: `ssd`/`hdd` when known |

### DisplayInfo

| Field         | Type      |
| ------------- | --------- |
| `width`       | `int`     |
| `height`      | `int`     |
| `scaleFactor` | `double`  |
| `refreshRate` | `double?` |

### Linux notes

- **`deviceId`**: DMI `product_uuid` when readable, otherwise `/etc/machine-id`, then `/var/lib/dbus/machine-id`. `product_uuid` is usually root-only (`0400`), so an **unprivileged process typically gets the machine-id while a root process gets the DMI UUID** — the id can differ by privilege level. Placeholder values (all-zero/all-F UUIDs, `uninitialized`) are skipped. Treat it as stable per (machine, privilege), not as a hardware-bound identifier; per machine-id(5) the machine-id is confidential, so hash it with an app-specific key if you transmit it. `serial` is likewise root-only and `null` otherwise.
- **Battery**: scans `/sys/class/power_supply/*` for `type=Battery` (peripheral batteries with `scope=Device` are skipped). `health` comes from the kernel `health` file when present (e.g. `Good`), otherwise `null`. Desktops without a battery return `null` fields.
- **Network**: one interface is chosen (up, non-loopback, has IPv4; the default-route interface from `/proc/net/route` is preferred, physical interfaces are preferred over docker/veth/bridge/tun) and `ipAddress`, `macAddress` and `networkType` all come from that same interface. Wi-Fi is detected via `/sys/class/net/<if>/wireless`.
- **Display**: uses GDK only (primary monitor, scale factor, refresh rate); no external tools such as `xrandr` are required or spawned. Without a display (headless) `width`/`height` are `0`.
- Build requires the GTK 3 development package (as for any Flutter Linux app).


### macOS notes

- **Network**: one interface is chosen (`SCDynamicStore` `State:/Network/Global/IPv4` → `PrimaryInterface` when it has a usable IPv4; otherwise the best physical `en*`/`eth*`). `ipAddress`, `macAddress` and `networkType` all come from that interface. Link-local (`169.254/16`) and Clash-style fake-IP (`198.18.0.0/15`) addresses are skipped. Type uses `SCNetworkInterfaceGetInterfaceType` (`IEEE80211` → `wifi`, `Ethernet` → `ethernet`).
- **Storage**: `storageType` is `ssd` or `hdd` from IOKit Device Characteristics `Medium Type` on the root volume's IOMedia (via DiskArbitration), else `null`.
- **Display**: physical pixels from `CGDisplayMode.pixelWidth/Height` (Retina-correct). Refresh rate from the display mode, or `NSScreen.maximumFramesPerSecond` when the mode reports 0.
- **Battery**: prefers a present `InternalBattery` source. `health` is `kIOPSBatteryHealthKey` (`Good`/`Fair`/`Poor`) when Apple publishes it; many Macs omit the key → `null`.


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
