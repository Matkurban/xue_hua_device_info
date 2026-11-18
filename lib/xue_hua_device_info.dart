import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'src/messages.g.dart';
import 'src/models.dart';

export 'src/models.dart';

/// Cross-platform device information client powered by Pigeon.
///
/// Supports Android (JNI Native Interop), iOS/macOS (Swift FFI Native Interop),
/// and Windows/Linux (Pigeon typed BasicMessageChannel).
/// Each subsystem (device identity, battery, network, storage, display) can be
/// queried independently without loading unrelated subsystems.
class XueHuaDeviceInfo {
  const XueHuaDeviceInfo._();

  static XueHuaDeviceInfoHostApi? _hostApiOverride;
  static XueHuaDeviceInfoHostApi? _defaultHostApi;

  static XueHuaDeviceInfoHostApi get _api =>
      _hostApiOverride ?? (_defaultHostApi ??= _createDefaultHostApi());

  static XueHuaDeviceInfoHostApi _createDefaultHostApi() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return XueHuaDeviceInfoHostApi.createWithNativeInteropApi();
    }
    return XueHuaDeviceInfoHostApi();
  }

  /// Overrides the underlying Pigeon [XueHuaDeviceInfoHostApi] for unit testing.
  @visibleForTesting
  static void setHostApiForTesting(XueHuaDeviceInfoHostApi? api) {
    _hostApiOverride = api;
  }

  /// Queries hardware identity, host name, and OS environment descriptors.
  static Future<DeviceInfo> getDeviceInfo() async {
    final pigeon = await _api.getDeviceInfo();
    return DeviceInfo.fromPigeon(pigeon);
  }

  /// Queries battery charge percentage, charging state, and health status.
  static Future<BatteryInfo> getBatteryInfo() async {
    final pigeon = await _api.getBatteryInfo();
    return BatteryInfo.fromPigeon(pigeon);
  }

  /// Queries active network transport, IPv4 address, MAC address, and interface name.
  static Future<NetworkInfo> getNetworkInfo() async {
    final pigeon = await _api.getNetworkInfo();
    return NetworkInfo.fromPigeon(pigeon);
  }

  /// Queries primary storage volume capacity, free space, and medium classification.
  static Future<StorageInfo> getStorageInfo() async {
    final pigeon = await _api.getStorageInfo();
    return StorageInfo.fromPigeon(pigeon);
  }

  /// Queries primary display physical resolution, density scale factor, and refresh rate.
  static Future<DisplayInfo> getDisplayInfo() async {
    final pigeon = await _api.getDisplayInfo();
    return DisplayInfo.fromPigeon(pigeon);
  }
}
