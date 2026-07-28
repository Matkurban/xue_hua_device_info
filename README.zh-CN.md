# xue_hua_device_info

[English](README.md) | **简体中文**

Flutter 设备信息插件：标识、电池、网络、存储、屏幕。

基于 **MethodChannel** 原生实现（Kotlin / Swift / C++）。不支持 Web。

---

## 支持平台

| 平台 | 支持 | 说明 |
| ---- | ---- | ---- |
| Android | 是 | Kotlin + MethodChannel |
| iOS | 是 | Swift + SPM/CocoaPods |
| macOS | 是 | Swift + SPM/CocoaPods |
| Windows | 是 | C++ + MethodChannel |
| Linux | 是 | C++ + MethodChannel |
| Web | 否 | 不支持 |

**要求：** Dart `^3.12.0`，Flutter `>=3.44.0`

---

## 安装

```yaml
dependencies:
  xue_hua_device_info: ^2.0.0
```

---

## 快速开始

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

无需调用 `initialize()`。

---

## API 概要

- `DeviceInfo`：`deviceId` / `manufacturer` / `model` / `serial`（桌面可选；移动端为 null）/ `name`
- `BatteryInfo`：`level` / `isCharging` / `health`
- `NetworkInfo`：`ipAddress` / `networkType` / `macAddress`（移动端为 null）
- `StorageInfo`：`totalBytes` / `freeBytes` / `storageType`
- `DisplayInfo`：`width` / `height` / `scaleFactor` / `refreshRate`

iOS **无法**通过公开 API 获取硬件序列号，因此 `serial` 为 `null`。

iOS 16+ 若未申请 `com.apple.developer.device-information.user-assigned-device-name` entitlement，`name` 通常是通用名（如 `"iPhone"`），不是用户设置的设备名。

---

## 2.0.0 破坏性变更

- 移除 Rust / flutter_rust_bridge / Cargokit
- 模型与字段重设计
- 移除 `initialize()`
- iOS 不再用 Keychain UUID 冒充 `serial`
