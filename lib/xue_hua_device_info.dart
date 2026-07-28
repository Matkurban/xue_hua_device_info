import 'src/models.dart';
import 'xue_hua_device_info_platform_interface.dart';

export 'src/models.dart';

/// Device information plugin for Android, iOS, Windows, macOS, and Linux.
///
/// Uses MethodChannel native implementations. Web is not supported.
class XueHuaDeviceInfo {
  const XueHuaDeviceInfo._();

  /// Returns device identity and hardware descriptors.
  static Future<DeviceInfo> getDeviceInfo() {
    return XueHuaDeviceInfoPlatform.instance.getDeviceInfo();
  }

  /// Returns battery status including level and charging state.
  static Future<BatteryInfo> getBatteryInfo() {
    return XueHuaDeviceInfoPlatform.instance.getBatteryInfo();
  }

  /// Returns network connection details.
  static Future<NetworkInfo> getNetworkInfo() {
    return XueHuaDeviceInfoPlatform.instance.getNetworkInfo();
  }

  /// Returns primary storage capacity.
  static Future<StorageInfo> getStorageInfo() {
    return XueHuaDeviceInfoPlatform.instance.getStorageInfo();
  }

  /// Returns primary display properties.
  static Future<DisplayInfo> getDisplayInfo() {
    return XueHuaDeviceInfoPlatform.instance.getDisplayInfo();
  }
}
