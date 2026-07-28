## 2.0.0

* **Breaking:** Replace Rust FFI (flutter_rust_bridge / Cargokit) with MethodChannel native plugins.
* **Breaking:** Redesign public models (`DeviceInfo`, `BatteryInfo`, `NetworkInfo`, `StorageInfo`, `DisplayInfo`).
* **Breaking:** Remove `initialize()`; MethodChannel needs no native library bootstrap.
* **Breaking:** iOS `serial` is no longer a Keychain UUID; hardware serial is unavailable via public APIs (`null`).
* Android uses Kotlin + `build.gradle.kts`; iOS/macOS ship SPM and CocoaPods dual support.
* Minimum SDK: Dart `^3.12.0`, Flutter `>=3.44.0`.

## 1.1.6

* Previous Rust FFI release. See git history for details.
