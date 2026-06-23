import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rust/api/device_info.dart' as rust;
import 'rust/frb_generated.dart';
import 'rust/models.dart';

export 'rust/models.dart';

const _channel = MethodChannel('xue_hua_device_info');

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

/// Device information plugin API.
///
/// Provides battery, network, storage, display, and device identity data
/// across Windows, macOS, Linux, iOS, and Android.
class XueHuaDeviceInfo {
  const XueHuaDeviceInfo._();

  /// Initializes the native Rust library. Call once before any other API.
  ///
  /// On Android the implementation uses Kotlin via [MethodChannel] and this is a
  /// no-op. On other platforms this loads the Rust FFI library.
  static Future<void> initialize() async {
    if (_isAndroid) {
      return;
    }
    await RustLib.init();
  }

  /// Returns device identification and hardware information.
  static Future<DeviceInfoResponse> getDeviceInfo() {
    if (_isAndroid) {
      return _invokeMap('getDeviceInfo').then(_parseDeviceInfo);
    }
    return rust.getDeviceInfo();
  }

  /// Returns battery status including charge level, charging state, and health.
  static Future<BatteryInfo> getBatteryInfo() {
    if (_isAndroid) {
      return _invokeMap('getBatteryInfo').then(_parseBatteryInfo);
    }
    return rust.getBatteryInfo();
  }

  /// Returns network connection details.
  static Future<NetworkInfo> getNetworkInfo() {
    if (_isAndroid) {
      return _invokeMap('getNetworkInfo').then(_parseNetworkInfo);
    }
    return rust.getNetworkInfo();
  }

  /// Returns storage capacity information for the primary disk.
  static Future<StorageInfo> getStorageInfo() {
    if (_isAndroid) {
      return _invokeMap('getStorageInfo').then(_parseStorageInfo);
    }
    return rust.getStorageInfo();
  }

  /// Returns display/screen information.
  static Future<DisplayInfo> getDisplayInfo() {
    if (_isAndroid) {
      return _invokeMap('getDisplayInfo').then(_parseDisplayInfo);
    }
    return rust.getDisplayInfo();
  }

  static Future<Map<dynamic, dynamic>> _invokeMap(String method) async {
    final result = await _channel.invokeMethod<Object?>(method);
    if (result is! Map) {
      throw PlatformException(
        code: 'INVALID_RESPONSE',
        message: '$method returned unexpected type: ${result.runtimeType}',
      );
    }
    return Map<dynamic, dynamic>.from(result);
  }

  static DeviceInfoResponse _parseDeviceInfo(Map<dynamic, dynamic> map) {
    return DeviceInfoResponse(
      uuid: map['uuid'] as String?,
      manufacturer: map['manufacturer'] as String?,
      model: map['model'] as String?,
      serial: map['serial'] as String?,
      androidId: map['android_id'] as String?,
      deviceName: map['device_name'] as String?,
    );
  }

  static BatteryInfo _parseBatteryInfo(Map<dynamic, dynamic> map) {
    return BatteryInfo(
      level: (map['level'] as num?)?.toDouble(),
      isCharging: map['isCharging'] as bool?,
      health: map['health'] as String?,
    );
  }

  static NetworkInfo _parseNetworkInfo(Map<dynamic, dynamic> map) {
    return NetworkInfo(
      ipAddress: map['ipAddress'] as String?,
      networkType: map['networkType'] as String?,
      macAddress: map['macAddress'] as String?,
    );
  }

  static StorageInfo _parseStorageInfo(Map<dynamic, dynamic> map) {
    return StorageInfo(
      totalSpace: _toBigInt(map['totalSpace']),
      freeSpace: _toBigInt(map['freeSpace']),
      storageType: map['storageType'] as String?,
    );
  }

  static DisplayInfo _parseDisplayInfo(Map<dynamic, dynamic> map) {
    return DisplayInfo(
      width: (map['width'] as num).toInt(),
      height: (map['height'] as num).toInt(),
      scaleFactor: (map['scaleFactor'] as num).toDouble(),
      refreshRate: (map['refreshRate'] as num?)?.toDouble(),
    );
  }

  static BigInt _toBigInt(Object? value) {
    if (value is BigInt) {
      return value;
    }
    if (value is int) {
      return BigInt.from(value);
    }
    if (value is num) {
      return BigInt.from(value.toInt());
    }
    throw PlatformException(
      code: 'INVALID_RESPONSE',
      message: 'Expected numeric storage value, got ${value.runtimeType}',
    );
  }
}
