import 'package:flutter/foundation.dart';

import '../messages.g.dart';

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

  /// Creates a [DeviceInfo] domain model from a Pigeon [PigeonDeviceInfo] message.
  factory DeviceInfo.fromPigeon(PigeonDeviceInfo message) {
    return DeviceInfo(
      deviceId: _nonEmptyOrNull(message.deviceId),
      manufacturer: _nonEmptyOrNull(message.manufacturer),
      model: _nonEmptyOrNull(message.model),
      serial: _nonEmptyOrNull(message.serial),
      name: _nonEmptyOrNull(message.name),
      operatingSystem: _nonEmptyOrNull(message.operatingSystem),
      osVersion: _nonEmptyOrNull(message.osVersion),
      architecture: _nonEmptyOrNull(message.architecture),
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
  DeviceInfo copyWith({
    String? deviceId,
    String? manufacturer,
    String? model,
    String? serial,
    String? name,
    String? operatingSystem,
    String? osVersion,
    String? architecture,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serial: serial ?? this.serial,
      name: name ?? this.name,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      osVersion: osVersion ?? this.osVersion,
      architecture: architecture ?? this.architecture,
    );
  }

  /// Converts this [DeviceInfo] into a Pigeon [PigeonDeviceInfo] message.
  PigeonDeviceInfo toPigeon() {
    return PigeonDeviceInfo(
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

  static String? _nonEmptyOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
