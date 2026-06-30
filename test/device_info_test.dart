import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

void main() {
  test('XueHuaDeviceInfo exposes static API methods', () {
    expect(XueHuaDeviceInfo.initialize, isA<Function>());
    expect(XueHuaDeviceInfo.getDeviceInfo, isA<Function>());
    expect(XueHuaDeviceInfo.getBatteryInfo, isA<Function>());
    expect(XueHuaDeviceInfo.getNetworkInfo, isA<Function>());
    expect(XueHuaDeviceInfo.getStorageInfo, isA<Function>());
    expect(XueHuaDeviceInfo.getDisplayInfo, isA<Function>());
  });
}
