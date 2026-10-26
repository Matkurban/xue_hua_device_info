# xue_hua_device_info

[English](README.md) | **简体中文**

Flutter 设备信息插件：标识、电池、网络、存储、屏幕。

基于 **MethodChannel** 原生实现（Kotlin / Swift / C++）。不支持 Web。

---

## 支持平台

| 平台    | 支持 | 说明                   |
| ------- | ---- | ---------------------- |
| Android | 是   | Kotlin + MethodChannel |
| iOS     | 是   | Swift + SPM/CocoaPods  |
| macOS   | 是   | Swift + SPM/CocoaPods  |
| Windows | 是   | C++ + MethodChannel    |
| Linux   | 是   | C++ + MethodChannel    |
| Web     | 否   | 不支持                 |

**要求：** Dart `^3.12.0`，Flutter `>=3.44.0`

---

## 安装

```yaml
dependencies:
  xue_hua_device_info: ^2.0.8
```

---

## Package skills

本包在 `skills/` 目录随包发布面向 AI 编码助手的 skill，逐项说明全部公开类与方法。

在依赖本包的应用项目中执行：

```bash
dart run skills@ get
```

安装名为 `xue_hua_device_info-usage` 的 skill（通常位于 `.agents/skills/`）。内容包括 `XueHuaDeviceInfo` 用法、模型字段、`PlatformException` 处理，以及各平台字段是否可空。

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

## Linux 说明

- **`deviceId`**：优先读取 DMI `product_uuid`，不可读时依次回退到 `/etc/machine-id`、`/var/lib/dbus/machine-id`。`product_uuid` 通常仅 root 可读，因此**普通用户进程一般得到 machine-id，root 进程得到 DMI UUID**，两者可能不同；全 0/全 F 的占位 UUID 及 `uninitialized` 会被跳过。按 machine-id(5)，machine-id 属保密信息，如需上传请用应用专属密钥做哈希。`serial` 同样仅 root 可读，否则为 `null`。
- **电池**：遍历 `/sys/class/power_supply/*`，选择 `type=Battery`（跳过 `scope=Device` 的外设电池）；`health` 来自内核 `health` 文件，不存在则为 `null`。无电池的台式机各字段为 `null`。
- **网络**：只选定一个网卡（已启用、非回环、有 IPv4；优先默认路由网卡，物理网卡优先于 docker/veth/网桥/tun），IP、MAC、网络类型都取自同一网卡。通过 `/sys/class/net/<if>/wireless` 识别 Wi-Fi。
- **显示**：仅使用 GDK（主显示器、缩放、刷新率），不再调用 `xrandr`。无显示环境（headless）下 `width`/`height` 为 `0`。

---

## 2.0.0 破坏性变更

- 移除 Rust / flutter_rust_bridge / Cargokit
- 模型与字段重设计
- 移除 `initialize()`
- iOS 不再用 Keychain UUID 冒充 `serial`
