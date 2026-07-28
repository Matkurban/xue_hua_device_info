import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_device_info/src/models.dart';
import 'package:xue_hua_device_info/xue_hua_device_info_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelXueHuaDeviceInfo();
  const channel = MethodChannel('xue_hua_device_info');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getDeviceInfo':
          return {
            'deviceId': 'abc',
            'manufacturer': 'Acme',
            'model': 'X1',
            'serial': null,
            'name': 'phone',
          };
        case 'getBatteryInfo':
          return {'level': 50, 'isCharging': true, 'health': 'good'};
        case 'getNetworkInfo':
          return {
            'ipAddress': '10.0.0.2',
            'networkType': 'wifi',
            'macAddress': null,
          };
        case 'getStorageInfo':
          return {
            'totalBytes': 2048,
            'freeBytes': 1024,
            'storageType': 'internal',
          };
        case 'getDisplayInfo':
          return {
            'width': 1440,
            'height': 3200,
            'scaleFactor': 3.0,
            'refreshRate': 120.0,
          };
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('method channel decodes maps including int level', () async {
    final device = await platform.getDeviceInfo();
    final battery = await platform.getBatteryInfo();
    final network = await platform.getNetworkInfo();
    final storage = await platform.getStorageInfo();
    final display = await platform.getDisplayInfo();

    expect(device.model, 'X1');
    expect(battery.level, 50);
    expect(battery.isCharging, isTrue);
    expect(network.ipAddress, '10.0.0.2');
    expect(storage.totalBytes, 2048);
    expect(display.refreshRate, 120);
  });

  test('method channel throws PlatformException on bad storage payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getStorageInfo') {
        return {'totalBytes': 'oops', 'freeBytes': 1};
      }
      return null;
    });

    expect(
      () => platform.getStorageInfo(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'bad_response'),
      ),
    );
  });

  test('method channel throws PlatformException on non-map response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return 'not-a-map';
    });

    expect(
      () => platform.getDeviceInfo(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'bad_response'),
      ),
    );
  });

  test('method channel throws PlatformException on wrong string type', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return {
        'deviceId': 42,
        'manufacturer': 'Acme',
        'model': 'X1',
      };
    });

    expect(
      () => platform.getDeviceInfo(),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'bad_response'),
      ),
    );
  });

  test('models support equality', () {
    expect(
      const DeviceInfo(deviceId: 'a', model: 'm'),
      const DeviceInfo(deviceId: 'a', model: 'm'),
    );
    expect(
      const BatteryInfo(level: 10, isCharging: false),
      const BatteryInfo(level: 10, isCharging: false),
    );
    expect(
      const StorageInfo(totalBytes: 1, freeBytes: 1),
      isNot(const StorageInfo(totalBytes: 2, freeBytes: 1)),
    );
    expect(
      const DisplayInfo(width: 1, height: 2, scaleFactor: 1),
      const DisplayInfo(width: 1, height: 2, scaleFactor: 1),
    );
  });
}
