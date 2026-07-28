import 'package:flutter/services.dart';

/// Device identity and hardware descriptors.
///
/// Field availability varies by platform. Missing values are `null`.
/// iOS does not expose a hardware serial number via public APIs.
class DeviceInfo {
  /// Platform durable device identifier (e.g. Android ID, IDFV, machine UUID).
  final String? deviceId;

  /// Device manufacturer when available.
  final String? manufacturer;

  /// Device model when available.
  final String? model;

  /// Hardware serial number when available (typically desktop only).
  final String? serial;

  /// User-visible device or host name when available.
  ///
  /// On iOS 16+, without the
  /// `com.apple.developer.device-information.user-assigned-device-name`
  /// entitlement this is typically a generic label (e.g. `"iPhone"`).
  final String? name;

  const DeviceInfo({
    this.deviceId,
    this.manufacturer,
    this.model,
    this.serial,
    this.name,
  });

  factory DeviceInfo.fromMap(Map<Object?, Object?> map) {
    try {
      return DeviceInfo(
        deviceId: _asString(map['deviceId']),
        manufacturer: _asString(map['manufacturer']),
        model: _asString(map['model']),
        serial: _asString(map['serial']),
        name: _asString(map['name']),
      );
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'Invalid DeviceInfo payload: $e',
      );
    }
  }

  Map<String, Object?> toMap() => {
        'deviceId': deviceId,
        'manufacturer': manufacturer,
        'model': model,
        'serial': serial,
        'name': name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          deviceId == other.deviceId &&
          manufacturer == other.manufacturer &&
          model == other.model &&
          serial == other.serial &&
          name == other.name;

  @override
  int get hashCode => Object.hash(deviceId, manufacturer, model, serial, name);

  @override
  String toString() =>
      'DeviceInfo(deviceId: $deviceId, manufacturer: $manufacturer, model: $model, serial: $serial, name: $name)';
}

/// Battery status.
class BatteryInfo {
  /// Charge level in percent (0–100), or `null` when unavailable.
  final double? level;

  /// Whether the device is charging, or `null` when unavailable.
  final bool? isCharging;

  /// Platform-specific health string when available.
  final String? health;

  const BatteryInfo({this.level, this.isCharging, this.health});

  factory BatteryInfo.fromMap(Map<Object?, Object?> map) {
    try {
      return BatteryInfo(
        level: _asDouble(map['level']),
        isCharging: _asBool(map['isCharging']),
        health: _asString(map['health']),
      );
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'Invalid BatteryInfo payload: $e',
      );
    }
  }

  Map<String, Object?> toMap() => {
        'level': level,
        'isCharging': isCharging,
        'health': health,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryInfo &&
          level == other.level &&
          isCharging == other.isCharging &&
          health == other.health;

  @override
  int get hashCode => Object.hash(level, isCharging, health);

  @override
  String toString() =>
      'BatteryInfo(level: $level, isCharging: $isCharging, health: $health)';
}

/// Network connection details.
class NetworkInfo {
  /// Local IPv4 address when available.
  final String? ipAddress;

  /// Connection type: `wifi`, `ethernet`, `cellular`, `none`, or `unknown`.
  final String? networkType;

  /// MAC address when available (typically desktop only; `null` on mobile).
  final String? macAddress;

  const NetworkInfo({this.ipAddress, this.networkType, this.macAddress});

  factory NetworkInfo.fromMap(Map<Object?, Object?> map) {
    try {
      return NetworkInfo(
        ipAddress: _asString(map['ipAddress']),
        networkType: _asString(map['networkType']),
        macAddress: _asString(map['macAddress']),
      );
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'Invalid NetworkInfo payload: $e',
      );
    }
  }

  Map<String, Object?> toMap() => {
        'ipAddress': ipAddress,
        'networkType': networkType,
        'macAddress': macAddress,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkInfo &&
          ipAddress == other.ipAddress &&
          networkType == other.networkType &&
          macAddress == other.macAddress;

  @override
  int get hashCode => Object.hash(ipAddress, networkType, macAddress);

  @override
  String toString() =>
      'NetworkInfo(ipAddress: $ipAddress, networkType: $networkType, macAddress: $macAddress)';
}

/// Primary storage capacity.
class StorageInfo {
  /// Total capacity in bytes.
  final int totalBytes;

  /// Free space in bytes.
  final int freeBytes;

  /// Storage technology or kind when available (e.g. `ssd`, `hdd`, `internal`).
  final String? storageType;

  const StorageInfo({
    required this.totalBytes,
    required this.freeBytes,
    this.storageType,
  });

  factory StorageInfo.fromMap(Map<Object?, Object?> map) {
    try {
      return StorageInfo(
        totalBytes: _requireInt(map['totalBytes'], 'totalBytes'),
        freeBytes: _requireInt(map['freeBytes'], 'freeBytes'),
        storageType: _asString(map['storageType']),
      );
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'Invalid StorageInfo payload: $e',
      );
    }
  }

  Map<String, Object?> toMap() => {
        'totalBytes': totalBytes,
        'freeBytes': freeBytes,
        'storageType': storageType,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageInfo &&
          totalBytes == other.totalBytes &&
          freeBytes == other.freeBytes &&
          storageType == other.storageType;

  @override
  int get hashCode => Object.hash(totalBytes, freeBytes, storageType);

  @override
  String toString() =>
      'StorageInfo(totalBytes: $totalBytes, freeBytes: $freeBytes, storageType: $storageType)';
}

/// Primary display properties.
class DisplayInfo {
  /// Physical width in pixels.
  final int width;

  /// Physical height in pixels.
  final int height;

  /// Scale factor (logical to physical).
  final double scaleFactor;

  /// Refresh rate in Hz when available.
  final double? refreshRate;

  const DisplayInfo({
    required this.width,
    required this.height,
    required this.scaleFactor,
    this.refreshRate,
  });

  factory DisplayInfo.fromMap(Map<Object?, Object?> map) {
    try {
      return DisplayInfo(
        width: _requireInt(map['width'], 'width'),
        height: _requireInt(map['height'], 'height'),
        scaleFactor: _requireDouble(map['scaleFactor'], 'scaleFactor'),
        refreshRate: _asDouble(map['refreshRate']),
      );
    } on PlatformException {
      rethrow;
    } catch (e) {
      throw PlatformException(
        code: 'bad_response',
        message: 'Invalid DisplayInfo payload: $e',
      );
    }
  }

  Map<String, Object?> toMap() => {
        'width': width,
        'height': height,
        'scaleFactor': scaleFactor,
        'refreshRate': refreshRate,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayInfo &&
          width == other.width &&
          height == other.height &&
          scaleFactor == other.scaleFactor &&
          refreshRate == other.refreshRate;

  @override
  int get hashCode => Object.hash(width, height, scaleFactor, refreshRate);

  @override
  String toString() =>
      'DisplayInfo(width: $width, height: $height, scaleFactor: $scaleFactor, refreshRate: $refreshRate)';
}

String? _asString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  throw PlatformException(
    code: 'bad_response',
    message: 'Expected String?, got ${value.runtimeType}',
  );
}

bool? _asBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  throw PlatformException(
    code: 'bad_response',
    message: 'Expected bool?, got ${value.runtimeType}',
  );
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw PlatformException(
    code: 'bad_response',
    message: 'Expected num?, got ${value.runtimeType}',
  );
}

int _requireInt(Object? value, String field) {
  if (value is num) return value.toInt();
  throw PlatformException(
    code: 'bad_response',
    message: 'Expected num for $field, got ${value?.runtimeType}',
  );
}

double _requireDouble(Object? value, String field) {
  if (value is num) return value.toDouble();
  throw PlatformException(
    code: 'bad_response',
    message: 'Expected num for $field, got ${value?.runtimeType}',
  );
}
