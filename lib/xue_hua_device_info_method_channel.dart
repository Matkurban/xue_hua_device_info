import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models.dart';
import 'xue_hua_device_info_platform_interface.dart';

/// MethodChannel implementation of [XueHuaDeviceInfoPlatform].
class MethodChannelXueHuaDeviceInfo extends XueHuaDeviceInfoPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('xue_hua_device_info');

  Map<Object?, Object?> _requireMap(Object? raw, String method) {
    if (raw is Map) {
      return Map<Object?, Object?>.from(raw);
    }
    throw PlatformException(
      code: 'bad_response',
      message: '$method returned an unexpected response: $raw',
    );
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    final raw = await methodChannel.invokeMethod<Object?>('getDeviceInfo');
    try {
      return DeviceInfo.fromMap(_requireMap(raw, 'getDeviceInfo'));
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'getDeviceInfo decode failed: $e',
      );
    }
  }

  @override
  Future<BatteryInfo> getBatteryInfo() async {
    final raw = await methodChannel.invokeMethod<Object?>('getBatteryInfo');
    try {
      return BatteryInfo.fromMap(_requireMap(raw, 'getBatteryInfo'));
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'getBatteryInfo decode failed: $e',
      );
    }
  }

  @override
  Future<NetworkInfo> getNetworkInfo() async {
    final raw = await methodChannel.invokeMethod<Object?>('getNetworkInfo');
    try {
      return NetworkInfo.fromMap(_requireMap(raw, 'getNetworkInfo'));
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'getNetworkInfo decode failed: $e',
      );
    }
  }

  @override
  Future<StorageInfo> getStorageInfo() async {
    final raw = await methodChannel.invokeMethod<Object?>('getStorageInfo');
    try {
      return StorageInfo.fromMap(_requireMap(raw, 'getStorageInfo'));
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'getStorageInfo decode failed: $e',
      );
    }
  }

  @override
  Future<DisplayInfo> getDisplayInfo() async {
    final raw = await methodChannel.invokeMethod<Object?>('getDisplayInfo');
    try {
      return DisplayInfo.fromMap(_requireMap(raw, 'getDisplayInfo'));
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'getDisplayInfo decode failed: $e',
      );
    }
  }
}
