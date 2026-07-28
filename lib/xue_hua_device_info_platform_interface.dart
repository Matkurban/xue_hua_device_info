import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models.dart';
import 'xue_hua_device_info_method_channel.dart';

/// The interface that platform implementations of xue_hua_device_info must extend.
abstract class XueHuaDeviceInfoPlatform extends PlatformInterface {
  /// Constructs a [XueHuaDeviceInfoPlatform].
  XueHuaDeviceInfoPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaDeviceInfoPlatform _instance = MethodChannelXueHuaDeviceInfo();

  /// The default instance of [XueHuaDeviceInfoPlatform] to use.
  static XueHuaDeviceInfoPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaDeviceInfoPlatform] when they
  /// register themselves.
  static set instance(XueHuaDeviceInfoPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns device identity information.
  Future<DeviceInfo> getDeviceInfo() {
    throw UnimplementedError('getDeviceInfo() has not been implemented.');
  }

  /// Returns battery status.
  Future<BatteryInfo> getBatteryInfo() {
    throw UnimplementedError('getBatteryInfo() has not been implemented.');
  }

  /// Returns network connection details.
  Future<NetworkInfo> getNetworkInfo() {
    throw UnimplementedError('getNetworkInfo() has not been implemented.');
  }

  /// Returns primary storage capacity.
  Future<StorageInfo> getStorageInfo() {
    throw UnimplementedError('getStorageInfo() has not been implemented.');
  }

  /// Returns primary display properties.
  Future<DisplayInfo> getDisplayInfo() {
    throw UnimplementedError('getDisplayInfo() has not been implemented.');
  }
}
