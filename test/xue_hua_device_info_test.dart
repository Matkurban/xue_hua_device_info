import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_device_info/src/messages.g.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

class _FakeHostApi extends XueHuaDeviceInfoHostApi {
  @override
  Future<WireDeviceInfo> getDeviceInfo() async {
    return WireDeviceInfo(
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
  Future<WireBatteryInfo> getBatteryInfo() async {
    return WireBatteryInfo(
      level: 85.0,
      isCharging: true,
      chargingState: WireBatteryChargingState.charging,
      healthStatus: WireBatteryHealthStatus.good,
      health: 'good',
      hasBattery: true,
    );
  }

  @override
  Future<WireNetworkInfo> getNetworkInfo() async {
    return WireNetworkInfo(
      ipAddress: '192.168.1.20',
      connectionType: WireNetworkConnectionType.wifi,
      networkType: 'wifi',
      macAddress: 'aa:bb:cc:dd:ee:ff',
      interfaceName: 'en0',
    );
  }

  @override
  Future<WireStorageInfo> getStorageInfo() async {
    return WireStorageInfo(
      totalBytes: 512 * 1024 * 1024 * 1024,
      freeBytes: 256 * 1024 * 1024 * 1024,
      mediumType: WireStorageMediumType.ssd,
      storageType: 'ssd',
    );
  }

  @override
  Future<WireDisplayInfo> getDisplayInfo() async {
    return WireDisplayInfo(
      width: 3024,
      height: 1964,
      scaleFactor: 2.0,
      refreshRate: 120.0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelPrefix =
      'dev.flutter.pigeon.xue_hua_device_info.XueHuaDeviceInfoHostApi';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    XueHuaDeviceInfo.setHostApiForTesting(null);
    for (final method in const [
      'getDeviceInfo',
      'getBatteryInfo',
      'getNetworkInfo',
      'getStorageInfo',
      'getDisplayInfo',
    ]) {
      messenger.setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(
          '$channelPrefix.$method',
          XueHuaDeviceInfoHostApi.pigeonChannelCodec,
        ),
        null,
      );
    }
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

  test('Pigeon binary channel round-trips all five messages', () async {
    const codec = XueHuaDeviceInfoHostApi.pigeonChannelCodec;
    XueHuaDeviceInfo.setHostApiForTesting(XueHuaDeviceInfoHostApi());

    void mockMethod(String method, Object? payload) {
      messenger.setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>('$channelPrefix.$method', codec),
        (Object? message) async => <Object?>[payload],
      );
    }

    mockMethod(
      'getDeviceInfo',
      WireDeviceInfo(
        deviceId: 'chan-id',
        manufacturer: 'Acme',
        model: 'X1',
        name: 'workstation',
        operatingSystem: 'linux',
        osVersion: '6.12',
        architecture: 'x86_64',
      ),
    );
    mockMethod(
      'getBatteryInfo',
      WireBatteryInfo(
        level: 64.0,
        isCharging: false,
        chargingState: WireBatteryChargingState.discharging,
        healthStatus: WireBatteryHealthStatus.fair,
        health: 'Fair',
        hasBattery: true,
      ),
    );
    mockMethod(
      'getNetworkInfo',
      WireNetworkInfo(
        ipAddress: '10.8.0.2',
        connectionType: WireNetworkConnectionType.vpn,
        networkType: 'vpn',
        interfaceName: 'tun0',
      ),
    );
    mockMethod(
      'getStorageInfo',
      WireStorageInfo(
        totalBytes: 2048,
        freeBytes: 512,
        mediumType: WireStorageMediumType.nvme,
        storageType: 'nvme',
      ),
    );
    mockMethod(
      'getDisplayInfo',
      WireDisplayInfo(
        width: 3840,
        height: 2160,
        scaleFactor: 2.0,
        refreshRate: 60.0,
      ),
    );

    final device = await XueHuaDeviceInfo.getDeviceInfo();
    final battery = await XueHuaDeviceInfo.getBatteryInfo();
    final network = await XueHuaDeviceInfo.getNetworkInfo();
    final storage = await XueHuaDeviceInfo.getStorageInfo();
    final display = await XueHuaDeviceInfo.getDisplayInfo();

    expect(device.deviceId, 'chan-id');
    expect(device.manufacturer, 'Acme');
    expect(device.model, 'X1');
    expect(device.operatingSystem, 'linux');
    expect(device.architecture, 'x86_64');

    expect(battery.level, 64.0);
    expect(battery.chargingState, BatteryChargingState.discharging);
    expect(battery.healthStatus, BatteryHealthStatus.fair);

    expect(network.connectionType, NetworkConnectionType.vpn);
    expect(network.networkType, 'vpn');
    expect(network.ipAddress, '10.8.0.2');

    expect(storage.totalBytes, 2048);
    expect(storage.freeBytes, 512);
    expect(storage.mediumType, StorageMediumType.nvme);

    expect(display.physicalResolution, '3840x2160');
    expect(display.refreshRate, 60.0);
  });

  test('Wire enum mappings and domain edge cases behave consistently', () {
    for (final state in WireBatteryChargingState.values) {
      final mapped = BatteryChargingState.fromPigeon(state);
      expect(mapped.toPigeon(), state);
    }
    for (final health in WireBatteryHealthStatus.values) {
      final mapped = BatteryHealthStatus.fromPigeon(health);
      expect(mapped.toPigeon(), health);
    }
    for (final conn in WireNetworkConnectionType.values) {
      final mapped = NetworkConnectionType.fromPigeon(conn);
      expect(mapped.toPigeon(), conn);
    }
    for (final medium in WireStorageMediumType.values) {
      final mapped = StorageMediumType.fromPigeon(medium);
      expect(mapped.toPigeon(), medium);
    }

    // Battery clamps invalid negative/over-100 levels.
    final badBattery = BatteryInfo.fromPigeon(
      WireBatteryInfo(
        level: 140.0,
        isCharging: null,
        chargingState: WireBatteryChargingState.unknown,
        healthStatus: WireBatteryHealthStatus.unknown,
        health: '  ',
        hasBattery: false,
      ),
    );
    expect(badBattery.level, isNull);
    expect(badBattery.health, isNull);
    expect(badBattery.hasBattery, isFalse);

    // Network prefers resolved Wire enum over literal 'unknown' wire string.
    final wifiNet = NetworkInfo.fromPigeon(
      WireNetworkInfo(
        ipAddress: '192.168.1.5',
        connectionType: WireNetworkConnectionType.wifi,
        networkType: 'unknown',
      ),
    );
    expect(wifiNet.connectionType, NetworkConnectionType.wifi);
    expect(wifiNet.networkType, 'wifi');
    expect(wifiNet.isConnected, isTrue);

    // Unknown transport without IP is treated as disconnected; with IP, connected.
    const emptyUnknownNet = NetworkInfo();
    expect(emptyUnknownNet.isConnected, isFalse);
    const ipUnknownNet = NetworkInfo(ipAddress: '10.0.0.1');
    expect(ipUnknownNet.isConnected, isTrue);

    // Storage clamps negative sizes to 0.
    final clampedStorage = StorageInfo.fromPigeon(
      WireStorageInfo(
        totalBytes: -10,
        freeBytes: -5,
        mediumType: WireStorageMediumType.internalStorage,
        storageType: ' ',
      ),
    );
    expect(clampedStorage.totalBytes, 0);
    expect(clampedStorage.freeBytes, 0);
    expect(clampedStorage.mediumType, StorageMediumType.internal);
    expect(clampedStorage.storageType, 'internal');

    // Display sanitizes non-positive dimensions/scale/refreshRate.
    final clampedDisplay = DisplayInfo.fromPigeon(
      WireDisplayInfo(
        width: -100,
        height: -200,
        scaleFactor: 0,
        refreshRate: -1,
      ),
    );
    expect(clampedDisplay.width, 0);
    expect(clampedDisplay.height, 0);
    expect(clampedDisplay.scaleFactor, 1.0);
    expect(clampedDisplay.refreshRate, isNull);
  });

  test('models support equality, copyWith with clear flags, toPigeon, and toMap', () {
    const dev = DeviceInfo(deviceId: 'a', manufacturer: 'Apple', model: 'M4');
    expect(dev, const DeviceInfo(deviceId: 'a', manufacturer: 'Apple', model: 'M4'));
    expect(dev.copyWith(name: 'Pro').name, 'Pro');
    expect(dev.copyWith(clearDeviceId: true).deviceId, isNull);
    expect(dev.toMap()['deviceId'], 'a');
    expect(DeviceInfo.fromPigeon(dev.toPigeon()), dev);

    const bat = BatteryInfo(
      level: 50,
      isCharging: false,
      chargingState: BatteryChargingState.discharging,
      healthStatus: BatteryHealthStatus.good,
      health: 'good',
      hasBattery: true,
    );
    expect(bat.copyWith(level: 60).level, 60);
    expect(bat.copyWith(clearLevel: true, clearHealth: true).level, isNull);
    expect(bat.toMap()['chargingState'], 'discharging');
    expect(BatteryInfo.fromPigeon(bat.toPigeon()), bat);

    const net = NetworkInfo(
      ipAddress: '10.0.0.2',
      connectionType: NetworkConnectionType.ethernet,
      networkType: 'ethernet',
      interfaceName: 'eth0',
    );
    expect(net.copyWith(ipAddress: '10.0.0.3').ipAddress, '10.0.0.3');
    expect(net.copyWith(clearIpAddress: true).ipAddress, isNull);
    expect(
      net.copyWith(connectionType: NetworkConnectionType.vpn).networkType,
      'vpn',
    );
    expect(net.toMap()['connectionType'], 'ethernet');
    expect(NetworkInfo.fromPigeon(net.toPigeon()), net);

    const store = StorageInfo(
      totalBytes: 1000,
      freeBytes: 400,
      mediumType: StorageMediumType.ssd,
      storageType: 'ssd',
    );
    expect(store.usedBytes, 600);
    expect(store.copyWith(freeBytes: 200).usedBytes, 800);
    expect(store.copyWith(clearStorageType: true).storageType, isNull);
    expect(StorageInfo.fromPigeon(store.toPigeon()), store);

    const disp = DisplayInfo(width: 1920, height: 1080, scaleFactor: 2.0);
    expect(disp.logicalWidth, 960.0);
    final hiRefresh = disp.copyWith(refreshRate: 144.0);
    expect(hiRefresh.isHighRefreshRate, isTrue);
    expect(hiRefresh.copyWith(clearRefreshRate: true).refreshRate, isNull);
    expect(DisplayInfo.fromPigeon(hiRefresh.toPigeon()), hiRefresh);
  });
}
