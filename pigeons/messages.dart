import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    appDirectory: 'example/',
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/xuehua/xue_hua_device_info/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.xuehua.xue_hua_device_info',
      useJni: true,
    ),
    swiftOut: <String>[
      'ios/xue_hua_device_info/Sources/xue_hua_device_info/Messages.g.swift',
      'macos/xue_hua_device_info/Sources/xue_hua_device_info/Messages.g.swift',
    ],
    swiftOptions: SwiftOptions(
      useFfi: true,
      ffiModuleName: 'xue_hua_device_info',
      configDirectory: '.',
    ),
    cppHeaderOut: 'windows/messages.g.h',
    cppSourceOut: 'windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'xue_hua_device_info'),
    gobjectHeaderOut: 'linux/messages.g.h',
    gobjectSourceOut: 'linux/messages.g.cc',
    gobjectOptions: GObjectOptions(module: 'XueHuaDeviceInfo'),
    dartPackageName: 'xue_hua_device_info',
  ),
)
/// Charging state reported by the host power subsystem.
enum WireBatteryChargingState {
  charging,
  discharging,
  full,
  notCharging,
  unknown,
}

/// Battery health classification reported by the host platform.
enum WireBatteryHealthStatus {
  good,
  fair,
  poor,
  overheat,
  dead,
  overVoltage,
  unspecifiedFailure,
  cold,
  unknown,
}

/// Active network transport classification.
enum WireNetworkConnectionType {
  wifi,
  ethernet,
  cellular,
  vpn,
  loopback,
  none,
  unknown,
}

/// Physical storage medium classification.
enum WireStorageMediumType {
  ssd,
  hdd,
  internalStorage,
  nvme,
  virtualDisk,
  unknown,
}

/// Strongly-typed Pigeon payload for device identity and system descriptors.
class WireDeviceInfo {
  const WireDeviceInfo({
    this.deviceId,
    this.manufacturer,
    this.model,
    this.serial,
    this.name,
    this.operatingSystem,
    this.osVersion,
    this.architecture,
  });

  final String? deviceId;
  final String? manufacturer;
  final String? model;
  final String? serial;
  final String? name;
  final String? operatingSystem;
  final String? osVersion;
  final String? architecture;
}

/// Strongly-typed Pigeon payload for battery status.
class WireBatteryInfo {
  const WireBatteryInfo({
    this.level,
    this.isCharging,
    required this.chargingState,
    required this.healthStatus,
    this.health,
    required this.hasBattery,
  });

  final double? level;
  final bool? isCharging;
  final WireBatteryChargingState chargingState;
  final WireBatteryHealthStatus healthStatus;
  final String? health;
  final bool hasBattery;
}

/// Strongly-typed Pigeon payload for network connection details.
class WireNetworkInfo {
  const WireNetworkInfo({
    this.ipAddress,
    required this.connectionType,
    required this.networkType,
    this.macAddress,
    this.interfaceName,
  });

  final String? ipAddress;
  final WireNetworkConnectionType connectionType;
  final String networkType;
  final String? macAddress;
  final String? interfaceName;
}

/// Strongly-typed Pigeon payload for primary storage capacity.
class WireStorageInfo {
  const WireStorageInfo({
    required this.totalBytes,
    required this.freeBytes,
    required this.mediumType,
    this.storageType,
  });

  final int totalBytes;
  final int freeBytes;
  final WireStorageMediumType mediumType;
  final String? storageType;
}

/// Strongly-typed Pigeon payload for primary display metrics.
class WireDisplayInfo {
  const WireDisplayInfo({
    required this.width,
    required this.height,
    required this.scaleFactor,
    this.refreshRate,
  });

  final int width;
  final int height;
  final double scaleFactor;
  final double? refreshRate;
}

/// Host API implemented by Android, iOS, macOS, Windows, and Linux plugins.
@HostApi()
abstract class XueHuaDeviceInfoHostApi {
  WireDeviceInfo getDeviceInfo();

  WireBatteryInfo getBatteryInfo();

  WireNetworkInfo getNetworkInfo();

  WireStorageInfo getStorageInfo();

  WireDisplayInfo getDisplayInfo();
}
