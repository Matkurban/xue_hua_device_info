# Change log

## 2.1.0

- **Core Architecture (Pigeon + Native Interop Migration):** Replaced `plugin_platform_interface` (`XueHuaDeviceInfoPlatform`) and handwritten `MethodChannel` (`MethodChannelXueHuaDeviceInfo`) with strongly-typed **Pigeon (`^30.0.4`)** `@HostApi` code generation (`pigeons/messages.dart`, `lib/src/messages.g.dart`), using **JNI Native Interop** (`useJni: true`, `messages.g.jni.dart`) on Android, **Swift FFI Native Interop** (`useFfi: true`, `messages.g.ffi.dart`) on iOS and macOS, and typed `BasicMessageChannel` C++/GObject bindings on Windows (`messages.g.h` / `messages.g.cpp`) and Linux (`messages.g.h` / `messages.g.cc`).
  **核心架构升级（Pigeon 迁移与 Native Interop）：** 移除 `plugin_platform_interface` 与手写 `MethodChannel` 实现，全面迁移至最新版 **Pigeon (`^30.0.4`)** 强类型 `@HostApi` 跨平台生成方案；Android 端启用 JNI Native Interop，iOS/macOS 端启用 Swift FFI Native Interop，Windows 与 Linux 端使用强类型 C++/GObject 通道通信。
- **Redesigned Modular Domain Models:** Split the monolithic `lib/src/models.dart` into dedicated model files under `lib/src/models/` (`device_enums.dart`, `device_info.dart`, `battery_info.dart`, `network_info.dart`, `storage_info.dart`, `display_info.dart`) with strongly-typed enums (`BatteryChargingState`, `BatteryHealthStatus`, `NetworkConnectionType`, `StorageMediumType`), extended fields (`operatingSystem`, `osVersion`, `architecture`, `hasBattery`, `interfaceName`, `usedBytes`), computed properties (`displayTitle`, `hasSerial`, `levelRatio`, `formattedLevel`, `isConnected`, `isWireless`, `usageRatio`, `usedPercentage`, `totalGigabytes`, `freeGigabytes`, `usedGigabytes`, `logicalWidth`, `logicalHeight`, `aspectRatio`, `physicalResolution`, `logicalResolution`, `isHighRefreshRate`), and `copyWith(..., clear*)` reset support.
  **数据模型全面重设计：** 将原有的单文件模型拆分为 `lib/src/models/` 下按职责独立的模型与枚举文件，新增强类型枚举（`BatteryChargingState`、`BatteryHealthStatus`、`NetworkConnectionType`、`StorageMediumType`）、扩展字段（`operatingSystem`、`osVersion`、`architecture`、`hasBattery`、`interfaceName`、`usedBytes`）、丰富的计算属性以及支持空值重置的 `copyWith(..., clear*)` 方法。
- **Native Fixes Across Platforms:** Fixed Android `TRANSPORT_VPN` classification to report `vpn`, guarded iOS `NWPathMonitor` `currentPath` access with locking and `UIWindowScene` screen lookup, matched macOS `NSScreen` cleanly via `CGMainDisplayID()`, fixed Windows `BatteryFlag == 255` unknown-status handling (plus `notCharging` when AC-powered), and mapped Linux sysfs battery `status` (`Charging`/`Discharging`/`Full`/`Not charging`) in `xue_hua_device_info_plugin.cc`.
  **五端原生实现修复：** 修复 Android VPN 类型未正确识别为 `vpn` 的问题；为 iOS `NWPathMonitor` 路径读取增加互斥锁并优先通过 `UIWindowScene` 获取屏幕；macOS 通过 `CGMainDisplayID()` 精确匹配主显示器；修复 Windows `BatteryFlag == 255` 误判充电的问题；完善 Linux sysfs `status` 对 `Full` 与 `Not charging` 状态的区分。
- **Example App (`signals_flutter` Fine-Grained State):** Refactored the example app (`example/lib/main.dart`, `example/lib/state/device_info_signals.dart`, `example/lib/widgets/device_section_card.dart`) to use `signals_flutter` (`Signal`, `SignalBuilder`, `SignalStatefulWidget`, `computed`, `batch`) with zero `setState` and explicit signal disposal. All 5 subsystems (Device Identity, Battery Status, Network Connection, Storage Capacity, Display Metrics) are fetched independently and displayed under separate titled cards showing every model property, keeping existing data visible alongside error banners on refresh failures.
  **示例应用重构（`signals_flutter` 精细化状态管理）：** 示例应用全面采用 `signals_flutter` 管理各模块状态，完全移除 `setState` 并完善控制器生命周期释放；5 大硬件信息模块按独立标题卡片分开展示全部字段，支持各模块独立异步获取与局部刷新（刷新失败时保留已加载数据并叠加错误提示横幅）。
- **Verification:** Passed `flutter analyze`, unit tests, widget tests, Android Kotlin unit tests, and end-to-end integration tests on macOS, Android emulator, and iOS Simulator (plus iOS simulator and device `--no-codesign` builds). Also verified Windows (`clang++ --target=x86_64-w64-mingw32 -std=c++17 -Wall -Wextra -Werror`) and Linux (`clang++ -std=c++14 -Wall -Wextra -Werror`) C++/GObject plugin sources against Flutter Engine C++ headers (`-Wno-unused-parameter` applied per-file to Pigeon-generated `messages.g.cpp` / `messages.g.cc`). Kept minimum SDK constraints compatible with `Dart ^3.12.0` and `Flutter >=3.44.0`.
  **编译与测试验证：** 通过 `flutter analyze`、单元测试、Widget 测试、Android Kotlin 单元测试，以及 macOS、Android 模拟器、iOS 模拟器的端到端 `integration_test` 与无签名 iOS 编译构建；同时在本地使用 `clang++`（Windows `mingw32` 头文件与 Linux `flutter_linux` + GTK/GLib 头文件替身）以 `-Wall -Wextra -Werror` 完成 Windows/Linux 插件手写源码零警告零错误编译验证（对 Pigeon 生成的 `messages.g.*` 按文件配置 `-Wno-unused-parameter`），并保持最低 SDK 约束为 Dart `^3.12.0`、Flutter `>=3.44.0`。

## 2.0.11

- Example: add `test_driver/integration_test.dart` for `flutter drive`; set example `version` so iOS CFBundleShortVersionString/CFBundleVersion are present (clears Xcode version warnings).
  示例：补充 `test_driver/integration_test.dart` 以支持 `flutter drive`；为 example 设置 `version`，使 iOS CFBundleShortVersionString/CFBundleVersion 有值（消除 Xcode 版本警告）。
- Verified iOS integration_test / flutter drive on ios17 / ios18 / ios26 / ios27 simulators with zero compile warnings.
  已在 ios17 / ios18 / ios26 / ios27 模拟器上验证 integration_test / flutter drive，且零编译警告。

## 2.0.10

- Android: prefer IPv4 from active `ConnectivityManager.getLinkProperties` (site-local first); fall back to filtered `NetworkInterface` scan; skip link-local (`169.254/16`) and Clash-style fake-IP (`198.18.0.0/15`).
- Android: report display size/refresh from `Display.getMode()` physical width/height and mode refresh rate (API 23+; minSdk 24), with `DisplayMetrics` fallback.
- Android: extract pure battery-health / IPv4 helpers for unit tests; keep `storageType` as `internal`; document Android network/display/storage notes.
- Example: assert `storageType == internal` on Android/iOS in integration tests.

## 2.0.9

- macOS: report physical Retina pixels via `CGDisplayMode.pixelWidth/Height` (was half-size from `CGDisplayPixelsWide/High` on HiDPI).
- macOS: fall back to `NSScreen.maximumFramesPerSecond` when `CGDisplayMode.refreshRate` is 0.
- macOS: fill `storageType` as `ssd`/`hdd` from IOKit `Device Characteristics` → `Medium Type` (`Solid State` / `Rotational`) via DiskArbitration `DADiskCopyIOMedia` (IOStorageDeviceCharacteristics.h).
- macOS: select one network interface (prefer `SCDynamicStore` `PrimaryInterface` with a usable IPv4) so IP, MAC and type stay consistent; skip RFC 3927 `169.254/16` and Clash fake-IP `198.18.0.0/15`; classify with `SCNetworkInterfaceGetInterfaceType`.
- macOS: prefer present `InternalBattery` power source; normalize level with `Max Capacity`; surface `kIOPSBatteryHealthKey` (`Good`/`Fair`/`Poor`) when published.
- iOS: skip link-local and fake-IP addresses when picking IPv4; prefer `en0` for Wi-Fi and `pdp_ip*` when `NWPathMonitor` reports cellular.
- Docs: macOS/iOS network, storage, display, and battery notes; platform-behavior skill reference.

## 2.0.8

- Windows: pick a single network adapter (prefer `GetBestInterfaceEx` physical Wi-Fi/Ethernet; deprioritize Hyper-V/VPN/tunnel adapters) so IP, MAC and type stay consistent.
- Windows: skip RFC 2544 `198.18.0.0/15` fake-IP addresses used by local proxies (Clash Meta, etc.).
- Windows: fill `storageType` as `ssd`/`hdd` via `IOCTL_STORAGE_QUERY_PROPERTY` + `StorageDeviceSeekPenaltyProperty` (Microsoft winioctl / Raymond Chen guidance).
- Windows: extract pure helpers to `device_info_helpers.{h,cpp}` with gtest coverage; compile with `/W4 /utf-8`.
- Example: migrate from deprecated `package:flutter/material.dart` to `package:material_ui/material_ui.dart` (Flutter 3.47+).
- Docs: update Windows network/storage notes in platform-behavior and README.

## 2.0.7

- Linux: fill `storageType` from `/sys/dev/block/<maj>:<min>/queue/rotational` (`0` → `ssd`, `1` → `hdd`), including partition parent and device-mapper `slaves` fallbacks (kernel Documentation/block/queue-sysfs.rst).
- Linux: deprioritize RFC 3927 link-local (`169.254.0.0/16`) addresses when selecting the network interface.
- Linux: classify bonding masters (`/sys/class/net/<if>/bonding` or `bond*` names) as ethernet instead of virtual.
- Linux: force NUL-terminate the `gethostname` buffer before copying into `DeviceInfo.name`.
- Linux: silence the CMake FetchContent `DOWNLOAD_EXTRACT_TIMESTAMP` author warning for googletest.
- Example: add `Key`s and richer summary lines; expand `integration_test` to exercise every public API and drive the refresh FAB (Flutter's supported successor to `flutter_driver`).

## 2.0.6

- Linux: read display info via GDK only (primary monitor, scale factor, `gdk_monitor_get_refresh_rate`); removed the blocking `popen("xrandr")` call and safely handles a missing display or monitor.
- Linux: network info now picks a single interface (up, non-loopback, IPv4; default route from `/proc/net/route` preferred, virtual docker/veth/bridge/tun interfaces deprioritized) and derives IP, MAC and type from it; Wi-Fi detected via `/sys/class/net/<if>/wireless`; interfaces whose names merely start with `lo` are no longer skipped.
- Linux: `deviceId` order is now documented and consistent: DMI `product_uuid` → `/etc/machine-id` → `/var/lib/dbus/machine-id`. Non-root processes usually fall back to the machine-id (see README).
- Linux: battery scans `/sys/class/power_supply/*` (`type=Battery`, skips `scope=Device`) and fills `health` from the `health` file when present.
- Linux: pure helpers moved to `device_info_helpers.{h,cc}` with real gtest unit tests (fake sysfs roots).

## 2.0.5

- Bump Windows/Linux native unit-test googletest to v1.18.0.
- Update the macOS podspec author contact email.

## 2.0.4

- Upgrade the Android toolchain to Android Gradle Plugin 9.1.0, Gradle 9.3.1, and Kotlin 2.4.0.

## 2.0.3

- Ship a package skill (`xue_hua_device_info-usage`) under `skills/` so consumers can install author-maintained agent instructions with `dart run skills@ get`.

## 2.0.2

- Bump Windows/Linux native unit-test googletest to v1.15.2 so CMake 4.x can configure the example.
- Fix Windows native compile: include Winsock2 before `windows.h` / Flutter headers so MSVC `/WX` no longer fails on winsock redefinitions.

## 2.0.1

- The Gradle tool version has been downgraded to 8.13.2.

## 2.0.0

- **Breaking:** Replace Rust FFI (flutter_rust_bridge / Cargokit) with MethodChannel native plugins.
- **Breaking:** Redesign public models (`DeviceInfo`, `BatteryInfo`, `NetworkInfo`, `StorageInfo`, `DisplayInfo`).
- **Breaking:** Remove `initialize()`; MethodChannel needs no native library bootstrap.
- **Breaking:** iOS `serial` is no longer a Keychain UUID; hardware serial is unavailable via public APIs (`null`).
- Android uses Kotlin + `build.gradle.kts`; iOS/macOS ship SPM and CocoaPods dual support.
- Minimum SDK: Dart `^3.12.0`, Flutter `>=3.44.0`.

## 1.1.6

- Previous Rust FFI release. See git history for details.
