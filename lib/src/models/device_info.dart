import 'package:flutter/foundation.dart';

import '../messages.g.dart';
import 'model_utils.dart';

/// Immutable snapshot of device identity, hardware descriptors, and OS environment.
@immutable
class DeviceInfo {
  const DeviceInfo({
    this.deviceId,
    this.manufacturer,
    this.model,
    this.serial,
    this.name,
    this.operatingSystem,
    this.osVersion,
    this.architecture,
  });

  /// Creates a [DeviceInfo] domain model from a Pigeon [WireDeviceInfo] message.
  factory DeviceInfo.fromPigeon(WireDeviceInfo message) {
    return DeviceInfo(
      deviceId: nonEmptyOrNull(message.deviceId),
      manufacturer: nonEmptyOrNull(message.manufacturer),
      model: nonEmptyOrNull(message.model),
      serial: nonEmptyOrNull(message.serial),
      name: nonEmptyOrNull(message.name),
      operatingSystem: nonEmptyOrNull(message.operatingSystem),
      osVersion: nonEmptyOrNull(message.osVersion),
      architecture: nonEmptyOrNull(message.architecture),
    );
  }

  /// Platform durable device identifier (e.g. Android ID, IDFV, IOPlatformUUID,
  /// Windows MachineGuid, or Linux DMI product_uuid / machine-id).
  final String? deviceId;

  /// Hardware manufacturer when available (e.g. `"Apple"`, `"Samsung"`, `"Dell Inc."`).
  final String? manufacturer;

  /// Device model or machine identifier when available.
  final String? model;

  /// Hardware serial number when available on desktop platforms; `null` on Android and iOS.
  final String? serial;

  /// User-visible device or host name when available.
  final String? name;

  /// Host operating system identifier (e.g. `"android"`, `"ios"`, `"macos"`, `"windows"`, `"linux"`).
  final String? operatingSystem;

  /// Host operating system version or release string when available.
  final String? osVersion;

  /// CPU architecture identifier (e.g. `"arm64"`, `"x86_64"`) when available.
  final String? architecture;

  /// Combined human-readable title combining [manufacturer] and [model].
  String get displayTitle {
    final mfg = manufacturer?.trim();
    final mdl = model?.trim();
    if (mfg != null && mfg.isNotEmpty && mdl != null && mdl.isNotEmpty) {
      if (mdl.toLowerCase().startsWith(mfg.toLowerCase())) {
        return mdl;
      }
      return '$mfg $mdl';
    }
    return mdl ?? mfg ?? name ?? 'Unknown Device';
  }

  /// Whether a hardware serial number is available on this platform.
  bool get hasSerial => serial != null && serial!.isNotEmpty;

  /// Returns a copy of this [DeviceInfo] with selectively overridden fields.
  ///
  /// Pass any `clear*` flag as `true` to explicitly reset a nullable field to `null`.
  DeviceInfo copyWith({
    String? deviceId,
    bool clearDeviceId = false,
    String? manufacturer,
    bool clearManufacturer = false,
    String? model,
    bool clearModel = false,
    String? serial,
    bool clearSerial = false,
    String? name,
    bool clearName = false,
    String? operatingSystem,
    bool clearOperatingSystem = false,
    String? osVersion,
    bool clearOsVersion = false,
    String? architecture,
    bool clearArchitecture = false,
  }) {
    return DeviceInfo(
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      manufacturer:
          clearManufacturer ? null : (manufacturer ?? this.manufacturer),
      model: clearModel ? null : (model ?? this.model),
      serial: clearSerial ? null : (serial ?? this.serial),
      name: clearName ? null : (name ?? this.name),
      operatingSystem:
          clearOperatingSystem ? null : (operatingSystem ?? this.operatingSystem),
      osVersion: clearOsVersion ? null : (osVersion ?? this.osVersion),
      architecture:
          clearArchitecture ? null : (architecture ?? this.architecture),
    );
  }

  /// Converts this [DeviceInfo] into a Pigeon [WireDeviceInfo] message.
  WireDeviceInfo toPigeon() {
    return WireDeviceInfo(
      deviceId: deviceId,
      manufacturer: manufacturer,
      model: model,
      serial: serial,
      name: name,
      operatingSystem: operatingSystem,
      osVersion: osVersion,
      architecture: architecture,
    );
  }

  /// Serializes this [DeviceInfo] to a structured key-value map.
  Map<String, Object?> toMap() => <String, Object?>{
    'deviceId': deviceId,
    'manufacturer': manufacturer,
    'model': model,
    'serial': serial,
    'name': name,
    'operatingSystem': operatingSystem,
    'osVersion': osVersion,
    'architecture': architecture,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          deviceId == other.deviceId &&
          manufacturer == other.manufacturer &&
          model == other.model &&
          serial == other.serial &&
          name == other.name &&
          operatingSystem == other.operatingSystem &&
          osVersion == other.osVersion &&
          architecture == other.architecture;

  @override
  int get hashCode => Object.hash(
    deviceId,
    manufacturer,
    model,
    serial,
    name,
    operatingSystem,
    osVersion,
    architecture,
  );

  @override
  String toString() =>
      'DeviceInfo(deviceId: $deviceId, manufacturer: $manufacturer, '
      'model: $model, serial: $serial, name: $name, '
      'operatingSystem: $operatingSystem, osVersion: $osVersion, '
      'architecture: $architecture)';
}
