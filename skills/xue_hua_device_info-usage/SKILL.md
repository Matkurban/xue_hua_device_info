---
name: xue_hua_device_info-usage
description: >-
  Use when writing, reviewing, or refactoring Dart/Flutter code that calls
  XueHuaDeviceInfo, DeviceInfo, BatteryInfo, NetworkInfo, StorageInfo, or
  DisplayInfo. Covers Pigeon-based device, battery, network, storage, and
  display APIs, rich domain models and enums, independent per-section fetching,
  and platform-specific field availability.
---

# xue_hua_device_info usage

Before generating or editing any call site, read:

- [references/api.md](references/api.md) — every public class, enum, constructor, method, and field
- [references/platform-behavior.md](references/platform-behavior.md) — per-platform field sources and nullability

## Guidelines

- Import `package:xue_hua_device_info/xue_hua_device_info.dart` for app code. That library exports `XueHuaDeviceInfo`, the five modular domain models (`DeviceInfo`, `BatteryInfo`, `NetworkInfo`, `StorageInfo`, `DisplayInfo`), and the four domain enums (`BatteryChargingState`, `BatteryHealthStatus`, `NetworkConnectionType`, `StorageMediumType`).
- Call the five **static** methods on `XueHuaDeviceInfo` (`getDeviceInfo()`, `getBatteryInfo()`, `getNetworkInfo()`, `getStorageInfo()`, `getDisplayInfo()`). Fetch only the subsystem(s) your screen or component actually needs rather than coupling all five calls into a single monolithic fetch when fine-grained loading is preferred.
- Version 2.1.0 replaced `plugin_platform_interface` (`XueHuaDeviceInfoPlatform`) and `MethodChannelXueHuaDeviceInfo` with **Pigeon (`^30.0.4`)** (`XueHuaDeviceInfoHostApi`), using JNI Native Interop on Android, Swift FFI Native Interop on iOS/macOS, and typed `BasicMessageChannel` on Windows/Linux. For unit tests, use `XueHuaDeviceInfo.setHostApiForTesting(mockHostApi)` with `Wire*` wire message classes (`package:xue_hua_device_info/src/messages.g.dart`).
- Supported platforms: Android, iOS, macOS, Windows, Linux. Web is not supported.
