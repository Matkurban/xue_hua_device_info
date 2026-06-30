import 'package:flutter/foundation.dart';

import 'rust/api/device_info.dart' as rust;
import 'rust/frb_generated.dart';
import 'rust/models.dart';

export 'rust/models.dart';

/// Device information plugin API.
///
/// Provides battery, network, storage, display, and device identity data
/// across Windows, macOS, Linux, iOS, and Android via Rust FFI.
class XueHuaDeviceInfo {
  const XueHuaDeviceInfo._();

  /// Initializes the native Rust library. Call once before any other API.
  static Future<void> initialize() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'xue_hua_device_info is not supported on web.',
      );
    }
    await RustLib.init();
  }

  /// Returns device identification and hardware information.
  static Future<DeviceInfoResponse> getDeviceInfo() => rust.getDeviceInfo();

  /// Returns battery status including charge level, charging state, and health.
  static Future<BatteryInfo> getBatteryInfo() => rust.getBatteryInfo();

  /// Returns network connection details.
  static Future<NetworkInfo> getNetworkInfo() => rust.getNetworkInfo();

  /// Returns storage capacity information for the primary disk.
  static Future<StorageInfo> getStorageInfo() => rust.getStorageInfo();

  /// Returns display/screen information.
  static Future<DisplayInfo> getDisplayInfo() => rust.getDisplayInfo();
}
