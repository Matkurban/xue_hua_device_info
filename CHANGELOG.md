## 1.1.1 

- fix ios build error


## 1.1.0

### Changed / 变更

- **Android 统一 Rust 实现** — 移除 Kotlin `MethodChannel` 业务逻辑，改为 Rust FFI + 薄 Kotlin plugin（`loadLibrary` + `ndk-context` 初始化），与 iOS/桌面使用同一 FRB seam。  
  **Android unified on Rust** — removed Kotlin `MethodChannel` business logic; Android now uses Rust FFI with a thin Kotlin plugin (`loadLibrary` + `ndk-context` init), sharing the same FRB seam as iOS/desktop.
- **Android 构建** — 需 Android NDK（由 [Cargokit](https://github.com/irondash/cargokit) 集成），与 `xue_hua_audio` 等插件一致。  
  **Android builds** — require the Android NDK (via Cargokit), consistent with `xue_hua_audio` and sibling plugins.
- **Dart facade** — 全平台统一 `RustLib.init()`；Web 调用 `initialize()` 时抛出 `UnsupportedError`。  
  **Dart facade** — all platforms use `RustLib.init()`; Web throws `UnsupportedError` from `initialize()`.
- **Rust 平台 router** — 新增 `PlatformDeviceInfo` trait，按 android / ios / desktop 分发。  
  **Rust platform router** — added `PlatformDeviceInfo` trait dispatching to android / ios / desktop adapters.

### Fixed / 修复

- **macOS** — 修复 `pmset` 输出 `"not charging"` 被误判为充电中的问题。  
  **macOS** — fixed `"not charging"` in `pmset` output being misread as charging.
- **Windows** — WMI/COM 失败时返回错误，不再静默返回空 `Ok`。  
  **Windows** — WMI/COM failures now return errors instead of silent empty `Ok`.
- **桌面电池** — `Full` 状态视为充电中。  
  **Desktop battery** — `Full` state counts as charging.
- **iOS** — 修复 `detect_network_type` 每次调用的内存泄漏；缩短网络类型检测等待。  
  **iOS** — fixed per-call memory leak in `detect_network_type`; reduced network detection wait.
- **Android 电量** — 过滤 `BATTERY_PROPERTY_CAPACITY` 返回的 `-1`（未知电量 → `null`）。  
  **Android battery** — filters `-1` from `BATTERY_PROPERTY_CAPACITY` (unknown level → `null`).

### Breaking / 破坏性变更

- **离线 IP** — iOS/Android 无 IPv4 时 `ipAddress` 为 `null`，不再返回 `"0.0.0.0"`。  
  **Offline IP** — `ipAddress` is `null` when no IPv4 is available on iOS/Android (no more `"0.0.0.0"`).
- **桌面 MAC** — 无法获取时 `macAddress` 为 `null`，不再返回 `"00:00:00:00:00:00"`。  
  **Desktop MAC** — `macAddress` is `null` when unavailable (no more `"00:00:00:00:00:00"`).
- **Android 错误类型** — 与 Rust 平台一致，经 FRB 抛出 `String` 错误（不再使用 `PlatformException`）。  
  **Android errors** — align with Rust platforms: FRB throws `String` errors (no more `PlatformException`).

## 1.0.1

- **macOS 链接错误** — 将 `sysinfo` 限制为 `system`、`disk`、`network` 特性，避免编入未使用的 `user` 模块（OpenDirectory 符号），修复 `Undefined symbols for architecture arm64` 构建失败。  
  **macOS link error** — restricted `sysinfo` to `system`, `disk`, and `network` features so the unused `user` module (OpenDirectory symbols) is not linked, fixing `Undefined symbols for architecture arm64` build failures.


## 1.0.0

首次正式发布。

Initial stable release.

### Added / 新增

- **`XueHuaDeviceInfo` 公开 API** — `initialize()` 及 5 个信息获取方法：  
  **`XueHuaDeviceInfo` public API** — `initialize()` plus 5 info getters:
  - `getDeviceInfo()` → `DeviceInfoResponse`
  - `getBatteryInfo()` → `BatteryInfo`
  - `getNetworkInfo()` → `NetworkInfo`
  - `getStorageInfo()` → `StorageInfo`
  - `getDisplayInfo()` → `DisplayInfo`
- **5 个数据模型** — 所有模型均从 `package:xue_hua_device_info/xue_hua_device_info.dart` 导出：  
  **5 data models** — all exported from `package:xue_hua_device_info/xue_hua_device_info.dart`:
  - `DeviceInfoResponse` — 设备标识与硬件信息 / device identity and hardware info
  - `BatteryInfo` — 电池状态 / battery status
  - `NetworkInfo` — 网络连接信息 / network connection details
  - `StorageInfo` — 主存储容量（`BigInt` 字节）/ primary storage capacity (`BigInt` bytes)
  - `DisplayInfo` — 主屏幕参数 / primary display properties
- **多平台支持** — Windows、macOS、Linux、iOS、Android：  
  **Multi-platform support** — Windows, macOS, Linux, iOS, Android:
  - Android：Kotlin `MethodChannel` 实现（移植自 tauri-plugin-device-info）  
    Android: Kotlin `MethodChannel` implementation (ported from tauri-plugin-device-info)
  - 桌面 / iOS：Rust + `flutter_rust_bridge` + [Cargokit](https://github.com/irondash/cargokit)  
    Desktop / iOS: Rust + `flutter_rust_bridge` + Cargokit
- **示例应用** — `example/` 目录下的完整演示 Dashboard  
  **Example app** — full demo dashboard in `example/`
- **集成测试** — `example/integration_test/simple_test.dart`  
  **Integration tests** — `example/integration_test/simple_test.dart`
- **Rust 单元测试** — `rust/` 目录下的模型序列化与解析测试  
  **Rust unit tests** — model serialization and parsing tests in `rust/`

### Notes / 说明

- **不支持 Web** — 插件依赖原生平台 API，无法在 Flutter Web 上运行。  
  **Web not supported** — the plugin relies on native platform APIs and cannot run on Flutter Web.
- **MAC 地址隐私限制** — iOS 返回 `"unavailable"`，Android 返回 `"restricted"`。  
  **MAC address privacy** — iOS returns `"unavailable"`, Android returns `"restricted"`.
- **部分字段可能为 `null`** — 受平台策略、硬件配置或权限限制影响（如台式机无电池、Linux 无 `xrandr`）。  
  **Some fields may be `null`** — due to platform policies, hardware configuration, or permissions (e.g. desktops without battery, Linux without `xrandr`).
- **设备信息采集逻辑** — 源自 [edisdev/tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info)（MIT）。  
  **Device info collection logic** — derived from [edisdev/tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info) (MIT).
