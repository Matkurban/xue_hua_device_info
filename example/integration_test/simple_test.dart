import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await XueHuaDeviceInfo.initialize();
  });

  testWidgets('device info APIs return data', (tester) async {
    final device = await XueHuaDeviceInfo.getDeviceInfo();
    expect(device, isA<DeviceInfoResponse>());

    final battery = await XueHuaDeviceInfo.getBatteryInfo();
    expect(battery, isA<BatteryInfo>());

    final network = await XueHuaDeviceInfo.getNetworkInfo();
    expect(network, isA<NetworkInfo>());
    expect(network.ipAddress, isNotNull);

    final storage = await XueHuaDeviceInfo.getStorageInfo();
    expect(storage, isA<StorageInfo>());
    expect(storage.totalSpace, greaterThan(BigInt.zero));

    final display = await XueHuaDeviceInfo.getDisplayInfo();
    expect(display, isA<DisplayInfo>());
    expect(display.width, greaterThan(0));
    expect(display.height, greaterThan(0));
  });
}
