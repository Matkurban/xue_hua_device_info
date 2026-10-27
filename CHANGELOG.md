# Change log

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
