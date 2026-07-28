import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';
import 'package:xue_hua_device_info/xue_hua_device_info_method_channel.dart';
import 'package:xue_hua_device_info/xue_hua_device_info_platform_interface.dart';

class MockXueHuaDeviceInfoPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaDeviceInfoPlatform {
  @override
  Future<DeviceInfo> getDeviceInfo() async {
    return const DeviceInfo(
      deviceId: 'id',
      manufacturer: 'Test',
      model: 'Model',
      name: 'Name',
    );
  }

  @override
  Future<BatteryInfo> getBatteryInfo() async {
    return const BatteryInfo(level: 80, isCharging: false, health: 'good');
  }

  @override
  Future<NetworkInfo> getNetworkInfo() async {
    return const NetworkInfo(
      ipAddress: '192.168.1.2',
      networkType: 'wifi',
    );
  }

  @override
  Future<StorageInfo> getStorageInfo() async {
    return const StorageInfo(
      totalBytes: 1000,
      freeBytes: 400,
      storageType: 'internal',
    );
  }

  @override
  Future<DisplayInfo> getDisplayInfo() async {
    return const DisplayInfo(
      width: 1080,
      height: 1920,
      scaleFactor: 2,
      refreshRate: 60,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    XueHuaDeviceInfoPlatform.instance = MethodChannelXueHuaDeviceInfo();
  });

  test('delegates to platform interface', () async {
    XueHuaDeviceInfoPlatform.instance = MockXueHuaDeviceInfoPlatform();

    final device = await XueHuaDeviceInfo.getDeviceInfo();
    final battery = await XueHuaDeviceInfo.getBatteryInfo();
    final network = await XueHuaDeviceInfo.getNetworkInfo();
    final storage = await XueHuaDeviceInfo.getStorageInfo();
    final display = await XueHuaDeviceInfo.getDisplayInfo();

    expect(device.deviceId, 'id');
    expect(battery.level, 80);
    expect(network.networkType, 'wifi');
    expect(storage.freeBytes, 400);
    expect(display.width, 1080);
  });
}
