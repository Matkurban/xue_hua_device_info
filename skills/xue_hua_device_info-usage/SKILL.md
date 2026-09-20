---
name: xue_hua_device_info-usage
description: >-
  Use when writing, reviewing, or refactoring Dart/Flutter code that calls
  XueHuaDeviceInfo, DeviceInfo, BatteryInfo, NetworkInfo, StorageInfo, or
  DisplayInfo. Covers MethodChannel device, battery, network, storage, and
  display APIs, PlatformException handling, nullable fields, and the fact
  that Web is not supported.
---

# xue_hua_device_info usage

Before generating or editing any call site, read:

- [references/api.md](references/api.md) — every public class, constructor, method, and field
- [references/platform-behavior.md](references/platform-behavior.md) — per-platform field sources and nullability

Use only APIs listed in those files. Do not invent methods, fields, enums, or a Web implementation.

## Guidelines

- Import `package:xue_hua_device_info/xue_hua_device_info.dart` for app code. That library exports `XueHuaDeviceInfo` and the five model classes.
- Call the five **static** methods on `XueHuaDeviceInfo`. The only constructor is `XueHuaDeviceInfo._()` (library-private). Do not write `XueHuaDeviceInfo()` or `new XueHuaDeviceInfo()`.
- Do not call `initialize()`. Version 2.0.0 removed it. MethodChannel needs no bootstrap.
- Call `WidgetsFlutterBinding.ensureInitialized()` before any plugin method.
- Supported platforms: Android, iOS, macOS, Windows, Linux. Web is not supported. Do not generate a Web plugin, `kIsWeb` fallbacks that pretend fields exist, or `dart:html` shims.
- Every getter returns a `Future`. Every model field that is documented as `T?` may be `null` on some or all platforms. Guard before using the value.
- Wrap calls in `try` / `on PlatformException`. Android native failures use code `native_error`. Decode failures use code `bad_response`. An unimplemented host (including Web) raises `MissingPluginException`.
- `networkType`, when present, is one of: `wifi`, `ethernet`, `cellular`, `none`, `unknown`. Treat any other string as unexpected, not as a new official value.
- `BatteryInfo.level` is a percent in `0`–`100` when non-null, as `double` (native ints are widened).
- `StorageInfo.totalBytes` and `freeBytes` are required `int`s (bytes). `DisplayInfo.width`, `height` are required `int`s (physical pixels); `scaleFactor` is a required `double`.
- `DeviceInfo.serial` is always `null` on Android and iOS. Do not invent a Keychain UUID or hardware serial on those platforms.
- `NetworkInfo.macAddress` is always `null` on Android and iOS.
- `BatteryInfo.health` is populated on Android only (`good`, `overheat`, `dead`, `over_voltage`, `unspecified_failure`, `cold`, or `unknown`). Other platforms return `null`.
- App code must not import or set `XueHuaDeviceInfoPlatform` / `MethodChannelXueHuaDeviceInfo`. Those types are for federated plugin implementations and tests only.
- Prefer `Future.wait` when loading several snapshots at once, as in the example app.

## Examples

### Basic setup

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

  debugPrint(device.model);
  debugPrint('${battery.level}');
  debugPrint(network.ipAddress);
  debugPrint('${storage.freeBytes}');
  debugPrint('${display.width}x${display.height}');
}
```

### Parallel fetch with error handling

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

Future<String> loadDeviceSummary() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final results = await Future.wait([
      XueHuaDeviceInfo.getDeviceInfo(),
      XueHuaDeviceInfo.getBatteryInfo(),
      XueHuaDeviceInfo.getNetworkInfo(),
      XueHuaDeviceInfo.getStorageInfo(),
      XueHuaDeviceInfo.getDisplayInfo(),
    ]);
    final device = results[0] as DeviceInfo;
    final battery = results[1] as BatteryInfo;
    final network = results[2] as NetworkInfo;
    final storage = results[3] as StorageInfo;
    final display = results[4] as DisplayInfo;

    final batteryText = battery.level == null ? 'unknown' : '${battery.level}%';
    final ip = network.ipAddress ?? 'none';
    return [
      '${device.manufacturer ?? 'unknown'} ${device.model ?? 'unknown'}',
      'battery=$batteryText charging=${battery.isCharging}',
      'net=${network.networkType} $ip',
      'storage=${storage.freeBytes}/${storage.totalBytes}',
      'display=${display.width}x${display.height} @${display.refreshRate}',
    ].join('\n');
  } on PlatformException catch (e) {
    return 'platform error ${e.code}: ${e.message}';
  } on MissingPluginException {
    return 'plugin unavailable on this platform';
  }
}
```
