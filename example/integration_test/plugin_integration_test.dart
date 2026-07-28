import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device info APIs return', (tester) async {
    final device = await XueHuaDeviceInfo.getDeviceInfo();
    final storage = await XueHuaDeviceInfo.getStorageInfo();
    final display = await XueHuaDeviceInfo.getDisplayInfo();

    expect(storage.totalBytes, greaterThanOrEqualTo(0));
    expect(display.width, greaterThan(0));
    expect(device, isNotNull);
  });
}
