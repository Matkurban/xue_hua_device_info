# xue_hua_device_info

Flutter 插件，用于获取设备标识、电池、网络、存储和屏幕等信息。

A Flutter plugin to access device information including battery, network, storage, display, and system details.

基于 [tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info)（MIT）移植，核心 Rust 逻辑通过 `flutter_rust_bridge` 暴露给 Dart。

Based on [tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info) (MIT). Core Rust logic is ported from that project and exposed via `flutter_rust_bridge`.

---

## 支持平台 / Supported Platforms

| Platform | 支持 / Support | 备注 / Notes |
| -------- | -------------- | ------------ |
| Windows  | Yes            | Rust + WMI   |
| macOS    | Yes            | Rust + system_profiler |
| Linux    | Yes            | Rust + `/sys` / `xrandr` |
| iOS      | Yes            | Rust + UIKit |
| Android  | Yes            | Rust + JNI + 薄 Kotlin init（Cargokit） |
| Web      | **No**         | 不支持 / Not supported |

---

## 安装 / Installation

在 `pubspec.yaml` 中添加依赖：

Add to your `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_device_info: ^1.0.0
```

本地开发可使用 path 依赖：

For local development:

```yaml
dependencies:
  xue_hua_device_info:
    path: ../xue_hua_device_info
```

---

## 快速开始 / Quick Start

```dart
import 'package:flutter/widgets.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

Future<void> main() async {
  // 1. 必须先初始化 Flutter 绑定
  // 1. Must initialize Flutter bindings first
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 初始化原生 Rust 库（全平台统一，含 Android）
  // 2. Initialize native Rust library (all platforms, including Android)
  await XueHuaDeviceInfo.initialize();

  // 3. 调用 API 获取设备信息
  // 3. Call APIs to fetch device information
  final device  = await XueHuaDeviceInfo.getDeviceInfo();
  final battery = await XueHuaDeviceInfo.getBatteryInfo();
  final network = await XueHuaDeviceInfo.getNetworkInfo();
  final storage = await XueHuaDeviceInfo.getStorageInfo();
  final display = await XueHuaDeviceInfo.getDisplayInfo();

  print('Device: ${device.model}');
  print('Battery: ${battery.level}%');
  print('IP: ${network.ipAddress}');
  print('Storage: ${storage.freeSpace} bytes free');
  print('Display: ${display.width}x${display.height}');
}
```

### 并行调用 / Parallel Calls

所有 API 均为 `static Future<...>`，可并行请求以提高性能：

All APIs are `static Future<...>` and can be called in parallel:

```dart
final results = await Future.wait([
  XueHuaDeviceInfo.getDeviceInfo(),
  XueHuaDeviceInfo.getBatteryInfo(),
  XueHuaDeviceInfo.getNetworkInfo(),
  XueHuaDeviceInfo.getStorageInfo(),
  XueHuaDeviceInfo.getDisplayInfo(),
]);

final device  = results[0] as DeviceInfoResponse;
final battery = results[1] as BatteryInfo;
final network = results[2] as NetworkInfo;
final storage = results[3] as StorageInfo;
final display = results[4] as DisplayInfo;
```

### 初始化说明 / Initialization Notes

| 平台 / Platform | `initialize()` 行为 / Behavior |
| --------------- | ------------------------------ |
| Android / iOS / Windows / macOS / Linux | 加载 Rust FFI 库（`RustLib.init()`）；Android 另由薄 Kotlin plugin 初始化 `ndk-context` |
| Web | 不支持 — `initialize()` 抛出 `UnsupportedError` |

**必须**在调用任何 API 之前完成 `WidgetsFlutterBinding.ensureInitialized()` 和 `XueHuaDeviceInfo.initialize()`（Web 除外）。

You **must** call `WidgetsFlutterBinding.ensureInitialized()` and `XueHuaDeviceInfo.initialize()` before any API call.

---

## API 参考 / API Reference

| 方法 / Method | 返回类型 / Returns | 说明 / Description |
| ------------- | ------------------ | ------------------ |
| `XueHuaDeviceInfo.initialize()` | `Future<void>` | 初始化原生库 / Initialize native library |
| `XueHuaDeviceInfo.getDeviceInfo()` | `Future<DeviceInfoResponse>` | 设备标识与硬件信息 / Device identity and hardware info |
| `XueHuaDeviceInfo.getBatteryInfo()` | `Future<BatteryInfo>` | 电池状态 / Battery status |
| `XueHuaDeviceInfo.getNetworkInfo()` | `Future<NetworkInfo>` | 网络连接信息 / Network connection details |
| `XueHuaDeviceInfo.getStorageInfo()` | `Future<StorageInfo>` | 主存储容量 / Primary storage capacity |
| `XueHuaDeviceInfo.getDisplayInfo()` | `Future<DisplayInfo>` | 主屏幕参数 / Primary display properties |

### 错误处理 / Error Handling

| 平台 / Platform | 异常类型 / Exception | 触发条件 / When |
| --------------- | -------------------- | --------------- |
| Android / Windows / macOS / Linux / iOS | `String`（经 flutter_rust_bridge 抛出） | Rust 层采集失败 |
| Web | `UnsupportedError` | 调用 `initialize()` 或任意 API |

示例 / Example:

```dart
try {
  final device = await XueHuaDeviceInfo.getDeviceInfo();
} on UnsupportedError catch (e) {
  // Web
  print('Unsupported: $e');
} catch (e) {
  // Rust platforms (including Android)
  print('Error: $e');
}
```

---

## 返回对象 / Data Models

以下模型均从 `package:xue_hua_device_info/xue_hua_device_info.dart` 导出。

All models are exported from `package:xue_hua_device_info/xue_hua_device_info.dart`.

---

### `DeviceInfoResponse`

设备标识与硬件信息。可用于设备指纹、分析或用户识别。

Device identification and hardware information. Useful for device fingerprinting, analytics, or user identification.

| 属性 / Property | 类型 / Type | 可空 / Nullable | 说明 / Description | 示例 / Example |
| --------------- | ----------- | --------------- | ------------------ | -------------- |
| `uuid` | `String?` | 是 / Yes | 硬件 UUID 或设备唯一标识 / Hardware UUID or unique device ID | `"12345678-1234-5678-9ABC-DEF012345678"` |
| `manufacturer` | `String?` | 是 / Yes | 制造商 / Manufacturer | `"Apple Inc."`, `"Dell Inc."`, `"samsung"` |
| `model` | `String?` | 是 / Yes | 设备型号 / Device model | `"MacBook Pro"`, `"SM-G991B"`, `"iPhone15,2"` |
| `serial` | `String?` | 是 / Yes | 序列号（部分平台受限）/ Serial number (may be restricted) | `"C02ABC123"` |
| `androidId` | `String?` | 是 / Yes | Android 设备 ID（**仅 Android**）/ Android device ID (**Android only**) | `"a1b2c3d4e5f67890"` |
| `deviceName` | `String?` | 是 / Yes | 用户设备名或主机名 / User-assigned device name or hostname | `"My MacBook"`, `"DESKTOP-ABC123"` |

**各平台 `uuid` 来源 / `uuid` source by platform:**

| 平台 / Platform | 来源 / Source |
| --------------- | ------------- |
| macOS           | `system_profiler` → `platform_UUID` |
| Windows         | WMI `Win32_ComputerSystemProduct.UUID` |
| Linux           | `/sys/class/dmi/id/product_uuid`，回退 `/etc/machine-id` |
| Android         | 同 `androidId`（`Settings.Secure.ANDROID_ID`） |
| iOS             | `UIDevice.identifierForVendor` |

**各平台 `serial` 来源 / `serial` source by platform:**

| 平台 / Platform | 来源 / Source |
| --------------- | ------------- |
| macOS           | `system_profiler` → `serial_number` |
| Windows         | WMI `Win32_BIOS.SerialNumber`，回退 `IdentifyingNumber` |
| Linux           | `/sys/class/dmi/id/product_serial` |
| Android         | 回退为 `androidId` |
| iOS             | Keychain 持久化 UUID（应用卸载重装后保持不变） |

---

### `BatteryInfo`

电池状态与健康信息。

Battery status and health information.

| 属性 / Property | 类型 / Type | 可空 / Nullable | 说明 / Description | 示例 / Example |
| --------------- | ----------- | --------------- | ------------------ | -------------- |
| `level` | `double?` | 是 / Yes | 当前电量百分比（0–100）/ Current charge level (0–100) | `85.0` |
| `isCharging` | `bool?` | 是 / Yes | 是否正在充电 / Whether device is charging | `true` |
| `health` | `String?` | 是 / Yes | 电池健康状态 / Battery health status | `"Good"`, `"95.0"` |

**`health` 可能值 / Possible `health` values:**

| 平台 / Platform | 值 / Values |
| --------------- | ----------- |
| Android         | `"Good"`, `"Overheat"`, `"Dead"`, `"Over Voltage"`, `"Unspecified Failure"`, `"Cold"`, `"Unknown"` |
| macOS           | `"Good"`（若检测到电池） |
| iOS             | `"Unknown"`, `"Good"`, `"Good (Charging)"`, `"Good (Full)"` |
| Windows / Linux | 健康度百分比字符串，如 `"95.0"` / Health percentage string, e.g. `"95.0"` |

> **注意 / Note:** 无电池设备（如台式机）可能返回全 `null` 或默认值。  
> Devices without a battery (e.g. desktops) may return all `null` or default values.

---

### `NetworkInfo`

网络连接详情。

Network connection details.

| 属性 / Property | 类型 / Type | 可空 / Nullable | 说明 / Description | 示例 / Example |
| --------------- | ----------- | --------------- | ------------------ | -------------- |
| `ipAddress` | `String?` | 是 / Yes | 本地 IPv4 地址 / Local IPv4 address | `"192.168.1.100"` |
| `networkType` | `String?` | 是 / Yes | 连接类型 / Connection type | `"wifi"`, `"ethernet"`, `"cellular"` |
| `macAddress` | `String?` | 是 / Yes | MAC 地址 / MAC address | 见下方平台说明 / See platform notes below |

**`networkType` 可能值 / Possible `networkType` values:**

| 值 / Value | 说明 / Description |
| ---------- | ------------------ |
| `"wifi"` | Wi-Fi 连接 |
| `"ethernet"` | 有线以太网 |
| `"cellular"` | 蜂窝移动网络 |
| `"unknown"` | 未知或未识别 |
| `"no_connection"` | 无连接（iOS） |
| `"other"` | 其他类型（iOS） |

**`macAddress` 平台说明 / `macAddress` by platform:**

| 平台 / Platform | 返回值 / Returns |
| --------------- | ---------------- |
| iOS             | `"unavailable"`（隐私限制） |
| Android         | `"restricted"`（隐私限制） |
| Windows / macOS / Linux | 真实 MAC 地址，或 `null` |

> 无网络时 `ipAddress` 可能为 `null`（Android / iOS）。  
> When offline, `ipAddress` may be `null` (Android / iOS).

---

### `StorageInfo`

主存储容量与类型信息。

Primary storage capacity and type information.

| 属性 / Property | 类型 / Type | 可空 / Nullable | 说明 / Description | 示例 / Example |
| --------------- | ----------- | --------------- | ------------------ | -------------- |
| `totalSpace` | `BigInt` | 否 / No | 总容量（字节）/ Total capacity in bytes | `512000000000` |
| `freeSpace` | `BigInt` | 否 / No | 可用空间（字节）/ Available space in bytes | `128000000000` |
| `storageType` | `String?` | 是 / Yes | 存储类型 / Storage technology type | `"internal"`, `"Ssd"` |

> 使用 `BigInt` 而非 `int`，避免大容量存储溢出。  
> Uses `BigInt` instead of `int` to avoid overflow on large capacities.

**`storageType` 平台说明 / `storageType` by platform:**

| 平台 / Platform | 值 / Values | 统计范围 / Scope |
| --------------- | ----------- | ---------------- |
| Android         | `"internal"` | 内部数据分区（`Environment.getDataDirectory()`） |
| iOS             | `"internal"` | 用户主目录卷 |
| Windows / macOS / Linux | 磁盘类型 Debug 字符串，如 `"Ssd"`, `"Hdd"`, `"Unknown"` | 系统盘（`/` 或 `C:\`） |

**字节格式化示例 / Format bytes example:**

```dart
String formatBytes(BigInt? bytes) {
  if (bytes == null) return '—';
  final gb = bytes.toDouble() / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(2)} GB';
}
```

---

### `DisplayInfo`

主屏幕属性。

Primary display properties.

| 属性 / Property | 类型 / Type | 可空 / Nullable | 说明 / Description | 示例 / Example |
| --------------- | ----------- | --------------- | ------------------ | -------------- |
| `width` | `int` | 否 / No | 屏幕宽度（物理像素）/ Screen width in physical pixels | `2560` |
| `height` | `int` | 否 / No | 屏幕高度（物理像素）/ Screen height in physical pixels | `1440` |
| `scaleFactor` | `double` | 否 / No | 缩放因子 / Display scale factor | `2.0`（Retina） |
| `refreshRate` | `double?` | 是 / Yes | 刷新率（Hz）/ Refresh rate in Hz | `60.0`, `120.0` |

**`scaleFactor` 平台说明 / `scaleFactor` by platform:**

| 平台 / Platform | 说明 / Description |
| --------------- | ------------------ |
| macOS           | Retina 屏幕约 `2.0`（物理像素 / 逻辑像素） |
| Windows         | 系统 DPI / 96（如 150% 缩放 → `1.5`） |
| Android         | `DisplayMetrics.density` |
| iOS             | `UIScreen.scale` |
| Linux           | 默认 `1.0`（依赖 `xrandr` 获取分辨率） |

> 可变刷新率屏幕（如 ProMotion）在 macOS 上 `refreshRate` 可能为 `null`。  
> Variable refresh rate displays may return `null` for `refreshRate` on macOS.

---

## 平台差异速查表 / Platform Matrix

| 字段 / Field | Windows | macOS | Linux | iOS | Android |
| ------------ | ------- | ----- | ----- | --- | ------- |
| `uuid` | WMI UUID | platform_UUID | DMI UUID / machine-id | identifierForVendor | ANDROID_ID |
| `androidId` | — | — | — | — | ANDROID_ID |
| `serial` | BIOS Serial | system_profiler | DMI serial | Keychain UUID | = androidId |
| `macAddress` | 真实 MAC | 真实 MAC | 真实 MAC | `"unavailable"` | `"restricted"` |
| `storageType` | Ssd/Hdd/… | Ssd/Hdd/… | Ssd/Hdd/… | `"internal"` | `"internal"` |
| `storage` 范围 | 系统盘 C:\ | 系统盘 / | 系统盘 / | 用户主目录 | 内部数据分区 |
| `display` 来源 | GetSystemMetrics | CoreGraphics | xrandr | UIScreen | DisplayMetrics |
| 实现语言 / Impl | Rust | Rust | Rust | Rust | Rust + 薄 Kotlin init |

> Linux 屏幕信息依赖 `xrandr` 命令，Wayland-only 环境可能无法获取分辨率。  
> Linux display info requires the `xrandr` command; Wayland-only environments may not return resolution.

---

## 架构 / Architecture

```mermaid
flowchart LR
  Dart["Dart XueHuaDeviceInfo"] --> Rust["Rust via flutter_rust_bridge"]
  Kotlin["Android thin Kotlin init"] -.->|ndk-context| Rust
  Rust --> Desktop["desktop/ windows macos linux"]
  Rust --> Mobile["mobile/ ios android"]
```

| 层级 / Layer | 说明 / Description |
| ------------ | ------------------ |
| **Dart** | `XueHuaDeviceInfo` 门面，位于 `lib/src/device_info.dart` |
| **Android** | 薄 Kotlin plugin（`loadLibrary` + `initAndroid`）+ Rust JNI adapter（`rust/src/mobile/android.rs`） |
| **Desktop / iOS** | Rust + `flutter_rust_bridge`（`rust/src/desktop/`, `rust/src/mobile/ios.rs`） |
| **构建 / Build** | 全平台：[Cargokit](https://github.com/irondash/cargokit) 打包 Rust 库；Android 另需 NDK |

---

## 开发与测试 / Development

> **Android 构建说明 / Android build note:** Android 端通过 Cargokit 编译 Rust，需要配置 **Android NDK**（与 `xue_hua_audio` 等插件一致）。  
> The Android side builds Rust via Cargokit and requires the **Android NDK** (same as `xue_hua_audio` and sibling plugins).

修改 `rust/src/api/` 后重新生成 FRB 绑定：

Regenerate FRB bindings after changing `rust/src/api/`:

```bash
flutter_rust_bridge_codegen generate
```

运行示例应用：

Run the example app:

```bash
cd example
flutter run -d macos   # 或 windows / linux / ios / android
```

运行集成测试：

Run integration tests:

```bash
cd example
flutter test integration_test/simple_test.dart -d macos
```

运行 Rust 单元测试：

Run Rust unit tests:

```bash
cd rust
cargo test
```

---

## 致谢 / Attribution

设备信息采集逻辑源自 [edisdev/tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info)，基于 MIT 许可证。

Device information collection logic is derived from [edisdev/tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info), licensed under the MIT License.

## 许可证 / License

MIT
