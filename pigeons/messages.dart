import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/xuehua/xue_hua_device_info/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.xuehua.xue_hua_device_info'),
    swiftOut:
        'ios/xue_hua_device_info/Sources/xue_hua_device_info/Messages.g.swift',
    swiftOptions: SwiftOptions(),
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
enum PigeonBatteryChargingState {
  charging,
  discharging,
  full,
  notCharging,
  unknown,
}

/// Battery health classification reported by the host platform.
enum PigeonBatteryHealthStatus {
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
enum PigeonNetworkConnectionType {
  wifi,
  ethernet,
  cellular,
  vpn,
  loopback,
  none,
  unknown,
}

/// Physical storage medium classification.
enum PigeonStorageMediumType {
  ssd,
  hdd,
  internalStorage,
  nvme,
  virtualDisk,
  unknown,
}

/// Strongly-typed Pigeon payload for device identity and system descriptors.
class PigeonDeviceInfo {
  const PigeonDeviceInfo({
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
class PigeonBatteryInfo {
  const PigeonBatteryInfo({
    this.level,
    this.isCharging,
    required this.chargingState,
    required this.healthStatus,
    this.health,
    required this.hasBattery,
  });

  final double? level;
  final bool? isCharging;
  final PigeonBatteryChargingState chargingState;
  final PigeonBatteryHealthStatus healthStatus;
  final String? health;
  final bool hasBattery;
}

/// Strongly-typed Pigeon payload for network connection details.
class PigeonNetworkInfo {
  const PigeonNetworkInfo({
    this.ipAddress,
    required this.connectionType,
    required this.networkType,
    this.macAddress,
    this.interfaceName,
  });

  final String? ipAddress;
  final PigeonNetworkConnectionType connectionType;
  final String networkType;
  final String? macAddress;
  final String? interfaceName;
}

/// Strongly-typed Pigeon payload for primary storage capacity.
class PigeonStorageInfo {
  const PigeonStorageInfo({
    required this.totalBytes,
    required this.freeBytes,
    required this.mediumType,
    this.storageType,
  });

  final int totalBytes;
  final int freeBytes;
  final PigeonStorageMediumType mediumType;
  final String? storageType;
}

/// Strongly-typed Pigeon payload for primary display metrics.
class PigeonDisplayInfo {
  const PigeonDisplayInfo({
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
  PigeonDeviceInfo getDeviceInfo();

  PigeonBatteryInfo getBatteryInfo();

  PigeonNetworkInfo getNetworkInfo();

  PigeonStorageInfo getStorageInfo();

  PigeonDisplayInfo getDisplayInfo();
}
