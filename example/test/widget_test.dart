import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_device_info/src/messages.g.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';
import 'package:xue_hua_device_info_example/main.dart';

class _TestHostApi extends XueHuaDeviceInfoHostApi {
  int deviceCalls = 0;
  int batteryCalls = 0;
  int networkCalls = 0;
  int storageCalls = 0;
  int displayCalls = 0;
  bool failNextBatteryCall = false;

  void resetCounts() {
    deviceCalls = 0;
    batteryCalls = 0;
    networkCalls = 0;
    storageCalls = 0;
    displayCalls = 0;
  }

  @override
  Future<WireDeviceInfo> getDeviceInfo() async {
    deviceCalls++;
    return WireDeviceInfo(
      deviceId: 'test-id',
      manufacturer: 'Apple',
      model: 'MacBookPro',
      name: 'DevMac',
      operatingSystem: 'macos',
      osVersion: '15.0',
      architecture: 'arm64',
    );
  }

  @override
  Future<WireBatteryInfo> getBatteryInfo() async {
    batteryCalls++;
    if (failNextBatteryCall) {
      failNextBatteryCall = false;
      throw StateError('simulated battery failure');
    }
    return WireBatteryInfo(
      level: 92.0,
      isCharging: true,
      chargingState: WireBatteryChargingState.charging,
      healthStatus: WireBatteryHealthStatus.good,
      health: 'Good',
      hasBattery: true,
    );
  }

  @override
  Future<WireNetworkInfo> getNetworkInfo() async {
    networkCalls++;
    return WireNetworkInfo(
      ipAddress: '192.168.1.8',
      connectionType: WireNetworkConnectionType.wifi,
      networkType: 'wifi',
      macAddress: '00:11:22:33:44:55',
      interfaceName: 'en0',
    );
  }

  @override
  Future<WireStorageInfo> getStorageInfo() async {
    storageCalls++;
    return WireStorageInfo(
      totalBytes: 1000000,
      freeBytes: 400000,
      mediumType: WireStorageMediumType.ssd,
      storageType: 'ssd',
    );
  }

  @override
  Future<WireDisplayInfo> getDisplayInfo() async {
    displayCalls++;
    return WireDisplayInfo(
      width: 2560,
      height: 1600,
      scaleFactor: 2.0,
      refreshRate: 120.0,
    );
  }
}

Future<void> _scrollToWidget(
  WidgetTester tester,
  Key key, {
  double delta = 300,
}) async {
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
  tearDown(() {
    XueHuaDeviceInfo.setHostApiForTesting(null);
  });

  testWidgets('Example dashboard displays all 5 titled sections and supports independent refresh', (
    WidgetTester tester,
  ) async {
    final fakeApi = _TestHostApi();
    XueHuaDeviceInfo.setHostApiForTesting(fakeApi);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(fakeApi.deviceCalls, 1);
    expect(fakeApi.batteryCalls, 1);
    expect(fakeApi.networkCalls, 1);
    expect(fakeApi.storageCalls, 1);
    expect(fakeApi.displayCalls, 1);
    expect(find.text('已加载 5 / 5 模块'), findsOneWidget);

    // Top 3 cards + content
    expect(find.byKey(const Key('device_section_title')), findsOneWidget);
    expect(find.byKey(const Key('device_section_content')), findsOneWidget);
    expect(find.text('Apple MacBookPro'), findsOneWidget);

    await _scrollToWidget(tester, const Key('battery_section_content'));
    expect(find.byKey(const Key('battery_section_title')), findsOneWidget);
    expect(find.text('92.0%'), findsNWidgets(2));

    await _scrollToWidget(tester, const Key('network_section_content'));
    expect(find.byKey(const Key('network_section_title')), findsOneWidget);
    expect(find.text('192.168.1.8'), findsOneWidget);

    await _scrollToWidget(tester, const Key('storage_section_content'));
    expect(find.byKey(const Key('storage_section_title')), findsOneWidget);
    expect(find.text('ssd'), findsOneWidget);

    await _scrollToWidget(tester, const Key('display_section_content'));
    expect(find.byKey(const Key('display_section_title')), findsOneWidget);
    expect(find.text('2560x1600 px'), findsOneWidget);

    // Independent refresh of battery only should NOT invoke the other 4 APIs.
    fakeApi.resetCounts();
    await _scrollToWidget(
      tester,
      const Key('battery_section_fetch_button'),
      delta: -300,
    );
    await tester.tap(find.byKey(const Key('battery_section_fetch_button')));
    await tester.pumpAndSettle();

    expect(fakeApi.batteryCalls, 1);
    expect(fakeApi.deviceCalls, 0);
    expect(fakeApi.networkCalls, 0);
    expect(fakeApi.storageCalls, 0);
    expect(fakeApi.displayCalls, 0);

    // Error on subsequent refresh keeps previously loaded data visible alongside banner.
    fakeApi.failNextBatteryCall = true;
    await tester.tap(find.byKey(const Key('battery_section_fetch_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('battery_section_error')), findsOneWidget);
    expect(find.byKey(const Key('battery_section_content')), findsOneWidget);
  });
}
