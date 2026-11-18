# xue_hua_device_info

[English](README.md) | **简体中文**

Flutter 跨平台设备信息插件：设备标识、电池状态、网络连接、存储空间、显示屏参数。

基于 **Pigeon (`^30.0.4`)** 强类型跨平台通信生成（Android JNI / Apple Swift FFI 原生互操作 + Windows C++ / Linux GObject 强类型通道），移除了旧版 `plugin_platform_interface` 与手写 `MethodChannel`。不支持 Web。

---

## 支持平台

| 平台    | 支持 | 实现方式                                               |
| ------- | ---- | ------------------------------------------------------ |
| Android | 是   | Kotlin + Pigeon HostApi（JNI Native Interop）          |
| iOS     | 是   | Swift + Pigeon HostApi（FFI Native Interop, SPM/CocoaPods） |
| macOS   | 是   | Swift + Pigeon HostApi（FFI Native Interop, SPM/CocoaPods） |
| Windows | 是   | C++ + Pigeon HostApi（Typed BasicMessageChannel）      |
| Linux   | 是   | C++/GObject + Pigeon HostApi（Typed BasicMessageChannel） |
| Web     | 否   | 不支持                                                 |

**环境要求：** Dart `^3.12.0`，Flutter `>=3.44.0`

---

## 安装

```yaml
dependencies:
  xue_hua_device_info: ^2.1.0
```

---

## 快速开始（按模块独立获取）

```dart
import 'package:flutter/widgets.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 各模块支持按需独立调用，无需一次性拉取全部数据：
  final device = await XueHuaDeviceInfo.getDeviceInfo();
  final battery = await XueHuaDeviceInfo.getBatteryInfo();
  final network = await XueHuaDeviceInfo.getNetworkInfo();
  final storage = await XueHuaDeviceInfo.getStorageInfo();
  final display = await XueHuaDeviceInfo.getDisplayInfo();

  debugPrint('${device.displayTitle} (${device.operatingSystem} ${device.architecture})');
  debugPrint('电池: ${battery.formattedLevel}, 状态=${battery.chargingState.code}');
  debugPrint('网络: ${network.connectionType.code} (${network.ipAddress}) 网卡=${network.interfaceName}');
  debugPrint('存储: ${storage.usedGigabytes.toStringAsFixed(1)} / ${storage.totalGigabytes.toStringAsFixed(1)} GiB (${storage.mediumType.code})');
  debugPrint('屏幕: ${display.physicalResolution} (${display.logicalResolution} @ ${display.scaleFactor}x)');
}
```

---

## 模块化数据模型

- **`DeviceInfo`** (`lib/src/models/device_info.dart`)：`deviceId`、`manufacturer`、`model`、`serial`、`name`、`operatingSystem`、`osVersion`、`architecture` 以及计算属性 `displayTitle`、`hasSerial`。
- **`BatteryInfo`** (`lib/src/models/battery_info.dart`)：`level`、`levelRatio`、`formattedLevel`、`isCharging`、`chargingState` (`BatteryChargingState`)、`healthStatus` (`BatteryHealthStatus`)、`health`、`hasBattery`。
- **`NetworkInfo`** (`lib/src/models/network_info.dart`)：`ipAddress`、`connectionType` (`NetworkConnectionType`)、`networkType`、`macAddress`、`interfaceName`、`isConnected`、`isWireless`。
- **`StorageInfo`** (`lib/src/models/storage_info.dart`)：`totalBytes`、`freeBytes`、`usedBytes`、`usageRatio`、`usedPercentage`、`totalGigabytes`、`freeGigabytes`、`usedGigabytes`、`mediumType` (`StorageMediumType`)、`storageType`。
- **`DisplayInfo`** (`lib/src/models/display_info.dart`)：`width`、`height`、`scaleFactor`、`refreshRate`、`logicalWidth`、`logicalHeight`、`aspectRatio`、`physicalResolution`、`logicalResolution`、`isHighRefreshRate`。
