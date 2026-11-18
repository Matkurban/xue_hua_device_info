import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';
import 'package:xue_hua_device_info_example/main.dart' as app;

Future<void> _scrollToKey(WidgetTester tester, Key key, {double delta = 300}) async {
  final listScrollable = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  ).first;
  await tester.scrollUntilVisible(
    find.byKey(key),
    delta,
    scrollable: listScrollable,
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all public Pigeon APIs return coherent domain models', (
    tester,
  ) async {
    final device = await XueHuaDeviceInfo.getDeviceInfo();
    final battery = await XueHuaDeviceInfo.getBatteryInfo();
    final network = await XueHuaDeviceInfo.getNetworkInfo();
    final storage = await XueHuaDeviceInfo.getStorageInfo();
    final display = await XueHuaDeviceInfo.getDisplayInfo();

    // Device
    expect(device, isA<DeviceInfo>());
    expect(device.name, isNotNull);
    expect(device.name, isNotEmpty);
    expect(device.deviceId, isNotNull);
    expect(device.deviceId, isNotEmpty);
    expect(device.operatingSystem, isNotNull);

    // Battery
    expect(battery, isA<BatteryInfo>());
    if (battery.level != null) {
      expect(battery.level!, inInclusiveRange(0, 100));
      expect(battery.isCharging, isNotNull);
    }

    // Network
    expect(network, isA<NetworkInfo>());
    expect(
      network.networkType,
      anyOf('wifi', 'ethernet', 'cellular', 'vpn', 'loopback', 'none', 'unknown'),
    );
    if (network.networkType != 'none') {
      expect(network.ipAddress, isNotNull);
      expect(network.ipAddress, isNot(startsWith('127.')));
      expect(network.ipAddress, isNot(startsWith('169.254.')));
    }

    // Storage
    expect(storage.totalBytes, greaterThan(0));
    expect(storage.freeBytes, greaterThanOrEqualTo(0));
    expect(storage.freeBytes, lessThanOrEqualTo(storage.totalBytes));
    expect(storage.usedBytes, equals(storage.totalBytes - storage.freeBytes));
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      expect(storage.storageType, anyOf(isNull, 'ssd', 'hdd'));
    }
    if (Platform.isAndroid || Platform.isIOS) {
      expect(storage.storageType, 'internal');
      expect(storage.mediumType, StorageMediumType.internal);
    }
    if (Platform.isMacOS) {
      expect(display.width, greaterThanOrEqualTo(800));
      expect(display.height, greaterThanOrEqualTo(600));
    }

    // Display
    expect(display.width, greaterThan(0));
    expect(display.height, greaterThan(0));
    expect(display.scaleFactor, greaterThan(0));
    if (display.refreshRate != null) {
      expect(display.refreshRate!, greaterThan(0));
    }
  });

  testWidgets('example UI renders 5 independent sections and supports per-section refresh', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('已加载 5 / 5 模块'), findsOneWidget);

    for (final prefix in const [
      'device_section',
      'battery_section',
      'network_section',
      'storage_section',
      'display_section',
    ]) {
      await _scrollToKey(tester, Key('${prefix}_content'));
      expect(find.byKey(Key('${prefix}_card')), findsOneWidget);
      expect(find.byKey(Key('${prefix}_title')), findsOneWidget);
      expect(find.byKey(Key('${prefix}_content')), findsOneWidget);
    }

    await _scrollToKey(tester, const Key('device_section_fetch_button'), delta: -300);
    await tester.tap(find.byKey(const Key('device_section_fetch_button')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('#2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('refresh_fab')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('device_section_content')), findsOneWidget);
  });
}
