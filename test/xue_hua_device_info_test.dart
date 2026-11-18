import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_device_info/src/messages.g.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

class _FakeHostApi extends XueHuaDeviceInfoHostApi {
  @override
  Future<PigeonDeviceInfo> getDeviceInfo() async {
    return PigeonDeviceInfo(
      deviceId: 'id-001',
      manufacturer: 'Apple',
      model: 'Mac16,1',
      serial: 'C02XXXXX',
      name: 'MacBook Pro',
      operatingSystem: 'macos',
      osVersion: '15.4.0',
      architecture: 'arm64',
    );
  }

  @override
  Future<PigeonBatteryInfo> getBatteryInfo() async {
    return PigeonBatteryInfo(
      level: 85.0,
      isCharging: true,
      chargingState: PigeonBatteryChargingState.charging,
      healthStatus: PigeonBatteryHealthStatus.good,
      health: 'good',
      hasBattery: true,
    );
  }

  @override
  Future<PigeonNetworkInfo> getNetworkInfo() async {
    return PigeonNetworkInfo(
      ipAddress: '192.168.1.20',
      connectionType: PigeonNetworkConnectionType.wifi,
      networkType: 'wifi',
      macAddress: 'aa:bb:cc:dd:ee:ff',
      interfaceName: 'en0',
    );
  }

  @override
  Future<PigeonStorageInfo> getStorageInfo() async {
    return PigeonStorageInfo(
      totalBytes: 512 * 1024 * 1024 * 1024,
      freeBytes: 256 * 1024 * 1024 * 1024,
      mediumType: PigeonStorageMediumType.ssd,
      storageType: 'ssd',
    );
  }

  @override
  Future<PigeonDisplayInfo> getDisplayInfo() async {
    return PigeonDisplayInfo(
      width: 3024,
      height: 1964,
      scaleFactor: 2.0,
      refreshRate: 120.0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    XueHuaDeviceInfo.setHostApiForTesting(null);
  });

  test('delegates to Pigeon HostApi and maps rich domain models', () async {
    XueHuaDeviceInfo.setHostApiForTesting(_FakeHostApi());

    final device = await XueHuaDeviceInfo.getDeviceInfo();
    final battery = await XueHuaDeviceInfo.getBatteryInfo();
    final network = await XueHuaDeviceInfo.getNetworkInfo();
    final storage = await XueHuaDeviceInfo.getStorageInfo();
    final display = await XueHuaDeviceInfo.getDisplayInfo();

    expect(device.deviceId, 'id-001');
    expect(device.manufacturer, 'Apple');
    expect(device.model, 'Mac16,1');
    expect(device.serial, 'C02XXXXX');
    expect(device.hasSerial, isTrue);
    expect(device.operatingSystem, 'macos');
    expect(device.osVersion, '15.4.0');
    expect(device.architecture, 'arm64');
    expect(device.displayTitle, 'Apple Mac16,1');

    expect(battery.level, 85.0);
    expect(battery.levelRatio, closeTo(0.85, 0.0001));
    expect(battery.formattedLevel, '85.0%');
    expect(battery.isCharging, isTrue);
    expect(battery.chargingState, BatteryChargingState.charging);
    expect(battery.healthStatus, BatteryHealthStatus.good);
    expect(battery.health, 'good');
    expect(battery.hasBattery, isTrue);

    expect(network.ipAddress, '192.168.1.20');
    expect(network.connectionType, NetworkConnectionType.wifi);
    expect(network.networkType, 'wifi');
    expect(network.macAddress, 'aa:bb:cc:dd:ee:ff');
    expect(network.interfaceName, 'en0');
    expect(network.isConnected, isTrue);
    expect(network.isWireless, isTrue);

    expect(storage.totalBytes, 512 * 1024 * 1024 * 1024);
    expect(storage.freeBytes, 256 * 1024 * 1024 * 1024);
    expect(storage.usedBytes, 256 * 1024 * 1024 * 1024);
    expect(storage.usageRatio, closeTo(0.5, 0.0001));
    expect(storage.usedPercentage, closeTo(50.0, 0.01));
    expect(storage.totalGigabytes, closeTo(512.0, 0.01));
    expect(storage.mediumType, StorageMediumType.ssd);
    expect(storage.storageType, 'ssd');

    expect(display.width, 3024);
    expect(display.height, 1964);
    expect(display.scaleFactor, 2.0);
    expect(display.logicalWidth, 1512.0);
    expect(display.logicalHeight, 982.0);
    expect(display.physicalResolution, '3024x1964');
    expect(display.logicalResolution, '1512x982');
    expect(display.refreshRate, 120.0);
    expect(display.isHighRefreshRate, isTrue);
  });

  test('Pigeon binary channel round-trips custom messages', () async {
    const codec = XueHuaDeviceInfoHostApi.pigeonChannelCodec;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          BasicMessageChannel<Object?>(
            'dev.flutter.pigeon.xue_hua_device_info.XueHuaDeviceInfoHostApi.getDeviceInfo',
            codec,
          ),
          (Object? message) async {
            return <Object?>[
              PigeonDeviceInfo(
                deviceId: 'chan-id',
                manufacturer: 'Acme',
                model: 'X1',
                name: 'workstation',
                operatingSystem: 'linux',
                osVersion: '6.12',
                architecture: 'x86_64',
              ),
            ];
          },
        );

    final device = await XueHuaDeviceInfo.getDeviceInfo();
    expect(device.deviceId, 'chan-id');
    expect(device.manufacturer, 'Acme');
    expect(device.model, 'X1');
    expect(device.operatingSystem, 'linux');
    expect(device.architecture, 'x86_64');
  });

  test('models support equality, copyWith, and toMap', () {
    const dev = DeviceInfo(deviceId: 'a', manufacturer: 'Apple', model: 'M4');
    expect(dev, const DeviceInfo(deviceId: 'a', manufacturer: 'Apple', model: 'M4'));
    expect(dev.copyWith(name: 'Pro').name, 'Pro');
    expect(dev.toMap()['deviceId'], 'a');

    const bat = BatteryInfo(
      level: 50,
      isCharging: false,
      chargingState: BatteryChargingState.discharging,
      healthStatus: BatteryHealthStatus.good,
      health: 'good',
      hasBattery: true,
    );
    expect(bat.copyWith(level: 60).level, 60);
    expect(bat.toMap()['chargingState'], 'discharging');

    const net = NetworkInfo(
      ipAddress: '10.0.0.2',
      connectionType: NetworkConnectionType.ethernet,
      networkType: 'ethernet',
      interfaceName: 'eth0',
    );
    expect(net.copyWith(ipAddress: '10.0.0.3').ipAddress, '10.0.0.3');
    expect(net.toMap()['connectionType'], 'ethernet');

    const store = StorageInfo(
      totalBytes: 1000,
      freeBytes: 400,
      mediumType: StorageMediumType.ssd,
      storageType: 'ssd',
    );
    expect(store.usedBytes, 600);
    expect(store.copyWith(freeBytes: 200).usedBytes, 800);

    const disp = DisplayInfo(width: 1920, height: 1080, scaleFactor: 2.0);
    expect(disp.logicalWidth, 960.0);
    expect(disp.copyWith(refreshRate: 144.0).isHighRefreshRate, isTrue);
  });
}
