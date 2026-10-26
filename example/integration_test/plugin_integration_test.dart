import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';
import 'package:xue_hua_device_info_example/main.dart' as app;

/// Full-device exercises for every public API.
///
/// Uses Flutter's `integration_test` package (the supported successor to
/// `flutter_driver`) so the example UI can be driven with WidgetTester while
/// the real Linux MethodChannel plugin runs under the embedder.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all public APIs return coherent values', (tester) async {
    final device = await XueHuaDeviceInfo.getDeviceInfo();
    final battery = await XueHuaDeviceInfo.getBatteryInfo();
    final network = await XueHuaDeviceInfo.getNetworkInfo();
    final storage = await XueHuaDeviceInfo.getStorageInfo();
    final display = await XueHuaDeviceInfo.getDisplayInfo();

    // Device
    expect(device, isA<DeviceInfo>());
    expect(device.name, isNotNull);
    expect(device.name, isNotEmpty);
    // On VMs DMI is often unreadable for non-root; deviceId should still fall
    // back to /etc/machine-id.
    expect(device.deviceId, isNotNull);
    expect(device.deviceId, isNotEmpty);

    // Battery — desktop VMs typically have no battery.
    expect(battery, isA<BatteryInfo>());
    if (battery.level != null) {
      expect(battery.level!, inInclusiveRange(0, 100));
      expect(battery.isCharging, isNotNull);
    }

    // Network
    expect(network, isA<NetworkInfo>());
    expect(network.networkType, isNotNull);
    expect(
      network.networkType,
      anyOf('wifi', 'ethernet', 'cellular', 'none', 'unknown'),
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
    if (Platform.isLinux) {
      // Linux now reports ssd/hdd from queue/rotational when available.
      expect(storage.storageType, anyOf(isNull, 'ssd', 'hdd'));
    }

    // Display — under xvfb a virtual monitor is present.
    expect(display.width, greaterThan(0));
    expect(display.height, greaterThan(0));
    expect(display.scaleFactor, greaterThan(0));
    if (display.refreshRate != null) {
      expect(display.refreshRate!, greaterThan(0));
    }

    // ignore: avoid_print
    print(
      'PROBE device=$device battery=$battery network=$network '
      'storage=$storage display=$display',
    );
  });

  testWidgets('example UI loads and refresh FAB reloads summary', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final summary = find.byKey(const Key('device_info_summary'));
    expect(summary, findsOneWidget);

    final text = tester.widget<SelectableText>(summary).data ?? '';
    expect(text, isNot(contains('Loading...')));
    expect(text, isNot(startsWith('Error:')));
    expect(text, contains('Device:'));
    expect(text, contains('Battery:'));
    expect(text, contains('Network:'));
    expect(text, contains('Storage:'));
    expect(text, contains('Display:'));
    expect(text, contains('ID:'));

    await tester.tap(find.byKey(const Key('refresh_fab')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final text2 = tester.widget<SelectableText>(summary).data ?? '';
    expect(text2, isNot(startsWith('Error:')));
    expect(text2, contains('Device:'));
    expect(text2, contains('Storage:'));
  });
}
