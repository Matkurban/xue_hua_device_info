import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_device_info/src/messages.g.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';
import 'package:xue_hua_device_info_example/main.dart';

class _TestHostApi extends XueHuaDeviceInfoHostApi {
  @override
  Future<PigeonDeviceInfo> getDeviceInfo() async => PigeonDeviceInfo(
    deviceId: 'test-id',
    manufacturer: 'Apple',
    model: 'MacBookPro',
    name: 'DevMac',
    operatingSystem: 'macos',
    osVersion: '15.0',
    architecture: 'arm64',
  );

  @override
  Future<PigeonBatteryInfo> getBatteryInfo() async => PigeonBatteryInfo(
    level: 92.0,
    isCharging: true,
    chargingState: PigeonBatteryChargingState.charging,
    healthStatus: PigeonBatteryHealthStatus.good,
    health: 'Good',
    hasBattery: true,
  );

  @override
  Future<PigeonNetworkInfo> getNetworkInfo() async => PigeonNetworkInfo(
    ipAddress: '192.168.1.8',
    connectionType: PigeonNetworkConnectionType.wifi,
    networkType: 'wifi',
    macAddress: '00:11:22:33:44:55',
    interfaceName: 'en0',
  );

  @override
  Future<PigeonStorageInfo> getStorageInfo() async => PigeonStorageInfo(
    totalBytes: 1000000,
    freeBytes: 400000,
    mediumType: PigeonStorageMediumType.ssd,
    storageType: 'ssd',
  );

  @override
  Future<PigeonDisplayInfo> getDisplayInfo() async => PigeonDisplayInfo(
    width: 2560,
    height: 1600,
    scaleFactor: 2.0,
    refreshRate: 120.0,
  );
}

void main() {
  tearDown(() {
    XueHuaDeviceInfo.setHostApiForTesting(null);
  });

  testWidgets('Example dashboard displays segmented sections with signals', (
    WidgetTester tester,
  ) async {
    XueHuaDeviceInfo.setHostApiForTesting(_TestHostApi());
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('device_section_title')), findsOneWidget);
    expect(find.byKey(const Key('battery_section_title')), findsOneWidget);
    expect(find.byKey(const Key('network_section_title')), findsOneWidget);
  });
}
