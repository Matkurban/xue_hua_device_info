# Change log

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
