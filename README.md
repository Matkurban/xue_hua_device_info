# xue_hua_device_info

A Flutter plugin to access device information including battery, network, storage, display, and system details.

Based on [tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info) (MIT). Core Rust logic is ported from that project and exposed via `flutter_rust_bridge`.

## Supported platforms

| Platform | Support |
| -------- | ------- |
| Windows  | Yes     |
| macOS    | Yes     |
| Linux    | Yes     |
| iOS      | Yes     |
| Android  | Yes     |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_device_info:
    path: ../xue_hua_device_info
```

## Usage

```dart
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await XueHuaDeviceInfo.initialize();

  final device = await XueHuaDeviceInfo.getDeviceInfo();
  final battery = await XueHuaDeviceInfo.getBatteryInfo();
  final network = await XueHuaDeviceInfo.getNetworkInfo();
  final storage = await XueHuaDeviceInfo.getStorageInfo();
  final display = await XueHuaDeviceInfo.getDisplayInfo();

  print(device);
  print(battery);
  print(network);
  print(storage);
  print(display);
}
```

## API

| Method | Returns |
| ------ | ------- |
| `XueHuaDeviceInfo.getDeviceInfo()` | `DeviceInfoResponse` |
| `XueHuaDeviceInfo.getBatteryInfo()` | `BatteryInfo` |
| `XueHuaDeviceInfo.getNetworkInfo()` | `NetworkInfo` |
| `XueHuaDeviceInfo.getStorageInfo()` | `StorageInfo` |
| `XueHuaDeviceInfo.getDisplayInfo()` | `DisplayInfo` |

## Architecture

- **Dart**: `XueHuaDeviceInfo` facade in `lib/src/device_info.dart`
- **Desktop / iOS**: `flutter_rust_bridge` + Rust (`rust/src/desktop/`, `rust/src/mobile/ios.rs`)
- **Android**: Kotlin via `MethodChannel` (ported from [tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info)), no Rust JNI at runtime
- **Build**: [Cargokit](https://github.com/irondash/cargokit) bundles the Rust library for desktop and iOS

### Android note

Call `XueHuaDeviceInfo.initialize()` after `WidgetsFlutterBinding.ensureInitialized()`. On Android, `initialize()` is a no-op; APIs call the Kotlin plugin directly through `MethodChannel`.

## Development

Regenerate FRB bindings after changing `rust/src/api/`:

```bash
flutter_rust_bridge_codegen generate
```

Run the example app:

```bash
cd example
flutter run -d macos
```

Run integration tests:

```bash
cd example
flutter test integration_test/simple_test.dart -d macos
```

Run Rust unit tests:

```bash
cd rust
cargo test
```

## Attribution

Device information collection logic is derived from [edisdev/tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info), licensed under the MIT License.

## License

MIT
