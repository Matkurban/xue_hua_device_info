import '../messages.g.dart';

/// Charging state of the device battery.
enum BatteryChargingState {
  /// Battery is actively charging from an external power source.
  charging('charging'),

  /// Battery is discharging (unplugged or draining).
  discharging('discharging'),

  /// Battery is fully charged.
  full('full'),

  /// Device is connected to power, but battery is not currently charging.
  notCharging('not_charging'),

  /// Charging state is unavailable or no battery is installed.
  unknown('unknown');

  const BatteryChargingState(this.code);

  /// Canonical string code for serialization and display.
  final String code;

  /// Converts a Pigeon-generated [WireBatteryChargingState] into a domain [BatteryChargingState].
  static BatteryChargingState fromPigeon(WireBatteryChargingState state) {
    return switch (state) {
      WireBatteryChargingState.charging => BatteryChargingState.charging,
      WireBatteryChargingState.discharging => BatteryChargingState.discharging,
      WireBatteryChargingState.full => BatteryChargingState.full,
      WireBatteryChargingState.notCharging => BatteryChargingState.notCharging,
      WireBatteryChargingState.unknown => BatteryChargingState.unknown,
    };
  }

  /// Converts this domain [BatteryChargingState] into a Pigeon [WireBatteryChargingState].
  WireBatteryChargingState toPigeon() {
    return switch (this) {
      BatteryChargingState.charging => WireBatteryChargingState.charging,
      BatteryChargingState.discharging => WireBatteryChargingState.discharging,
      BatteryChargingState.full => WireBatteryChargingState.full,
      BatteryChargingState.notCharging => WireBatteryChargingState.notCharging,
      BatteryChargingState.unknown => WireBatteryChargingState.unknown,
    };
  }

  /// Resolves a [BatteryChargingState] from its string code or boolean charging flag.
  static BatteryChargingState fromCode(String? code, {bool? isCharging}) {
    switch (code?.trim().toLowerCase()) {
      case 'charging':
        return BatteryChargingState.charging;
      case 'discharging':
      case 'unplugged':
        return BatteryChargingState.discharging;
      case 'full':
        return BatteryChargingState.full;
      case 'not_charging':
      case 'not charging':
        return BatteryChargingState.notCharging;
    }
    if (isCharging == true) {
      return BatteryChargingState.charging;
    }
    if (isCharging == false) {
      return BatteryChargingState.discharging;
    }
    return BatteryChargingState.unknown;
  }
}

/// Physical health status of the device battery.
enum BatteryHealthStatus {
  /// Battery is operating within normal health parameters.
  good('good'),

  /// Battery health is fair / degraded (e.g. macOS IOKit `Fair`).
  fair('fair'),

  /// Battery health is poor and service is recommended.
  poor('poor'),

  /// Battery is overheating.
  overheat('overheat'),

  /// Battery is dead or non-functional.
  dead('dead'),

  /// Battery is experiencing over-voltage.
  overVoltage('over_voltage'),

  /// Battery experienced an unspecified failure.
  unspecifiedFailure('unspecified_failure'),

  /// Battery temperature is too cold.
  cold('cold'),

  /// Battery health is not exposed by the platform or unavailable.
  unknown('unknown');

  const BatteryHealthStatus(this.code);

  /// Canonical string code.
  final String code;

  /// Converts a Pigeon-generated [WireBatteryHealthStatus] into a domain [BatteryHealthStatus].
  static BatteryHealthStatus fromPigeon(WireBatteryHealthStatus status) {
    return switch (status) {
      WireBatteryHealthStatus.good => BatteryHealthStatus.good,
      WireBatteryHealthStatus.fair => BatteryHealthStatus.fair,
      WireBatteryHealthStatus.poor => BatteryHealthStatus.poor,
      WireBatteryHealthStatus.overheat => BatteryHealthStatus.overheat,
      WireBatteryHealthStatus.dead => BatteryHealthStatus.dead,
      WireBatteryHealthStatus.overVoltage => BatteryHealthStatus.overVoltage,
      WireBatteryHealthStatus.unspecifiedFailure =>
        BatteryHealthStatus.unspecifiedFailure,
      WireBatteryHealthStatus.cold => BatteryHealthStatus.cold,
      WireBatteryHealthStatus.unknown => BatteryHealthStatus.unknown,
    };
  }

  /// Converts this domain [BatteryHealthStatus] into a Pigeon [WireBatteryHealthStatus].
  WireBatteryHealthStatus toPigeon() {
    return switch (this) {
      BatteryHealthStatus.good => WireBatteryHealthStatus.good,
      BatteryHealthStatus.fair => WireBatteryHealthStatus.fair,
      BatteryHealthStatus.poor => WireBatteryHealthStatus.poor,
      BatteryHealthStatus.overheat => WireBatteryHealthStatus.overheat,
      BatteryHealthStatus.dead => WireBatteryHealthStatus.dead,
      BatteryHealthStatus.overVoltage => WireBatteryHealthStatus.overVoltage,
      BatteryHealthStatus.unspecifiedFailure =>
        WireBatteryHealthStatus.unspecifiedFailure,
      BatteryHealthStatus.cold => WireBatteryHealthStatus.cold,
      BatteryHealthStatus.unknown => WireBatteryHealthStatus.unknown,
    };
  }

  /// Resolves a [BatteryHealthStatus] from a platform health label.
  static BatteryHealthStatus fromLabel(String? label) {
    if (label == null || label.trim().isEmpty) {
      return BatteryHealthStatus.unknown;
    }
    switch (label.trim().toLowerCase()) {
      case 'good':
      case 'normal':
        return BatteryHealthStatus.good;
      case 'fair':
        return BatteryHealthStatus.fair;
      case 'poor':
      case 'check battery':
      case 'service recommended':
        return BatteryHealthStatus.poor;
      case 'overheat':
        return BatteryHealthStatus.overheat;
      case 'dead':
        return BatteryHealthStatus.dead;
      case 'over_voltage':
      case 'overvoltage':
        return BatteryHealthStatus.overVoltage;
      case 'unspecified_failure':
        return BatteryHealthStatus.unspecifiedFailure;
      case 'cold':
        return BatteryHealthStatus.cold;
      default:
        return BatteryHealthStatus.unknown;
    }
  }
}

/// Active network transport classification.
enum NetworkConnectionType {
  /// IEEE 802.11 wireless LAN (`wifi`).
  wifi('wifi'),

  /// Wired Ethernet or bonding interface (`ethernet`).
  ethernet('ethernet'),

  /// Mobile WWAN / cellular data (`cellular`).
  cellular('cellular'),

  /// Virtual private network or tunnel (`vpn`).
  vpn('vpn'),

  /// Loopback interface (`loopback`).
  loopback('loopback'),

  /// No active network connectivity (`none`).
  none('none'),

  /// Active network of an unrecognized transport (`unknown`).
  unknown('unknown');

  const NetworkConnectionType(this.code);

  /// Canonical wire/display string (`wifi`, `ethernet`, `cellular`, `none`, `unknown`).
  final String code;

  /// Converts a Pigeon-generated [WireNetworkConnectionType] into [NetworkConnectionType].
  static NetworkConnectionType fromPigeon(WireNetworkConnectionType type) {
    return switch (type) {
      WireNetworkConnectionType.wifi => NetworkConnectionType.wifi,
      WireNetworkConnectionType.ethernet => NetworkConnectionType.ethernet,
      WireNetworkConnectionType.cellular => NetworkConnectionType.cellular,
      WireNetworkConnectionType.vpn => NetworkConnectionType.vpn,
      WireNetworkConnectionType.loopback => NetworkConnectionType.loopback,
      WireNetworkConnectionType.none => NetworkConnectionType.none,
      WireNetworkConnectionType.unknown => NetworkConnectionType.unknown,
    };
  }

  /// Converts this domain [NetworkConnectionType] into a Pigeon [WireNetworkConnectionType].
  WireNetworkConnectionType toPigeon() {
    return switch (this) {
      NetworkConnectionType.wifi => WireNetworkConnectionType.wifi,
      NetworkConnectionType.ethernet => WireNetworkConnectionType.ethernet,
      NetworkConnectionType.cellular => WireNetworkConnectionType.cellular,
      NetworkConnectionType.vpn => WireNetworkConnectionType.vpn,
      NetworkConnectionType.loopback => WireNetworkConnectionType.loopback,
      NetworkConnectionType.none => WireNetworkConnectionType.none,
      NetworkConnectionType.unknown => WireNetworkConnectionType.unknown,
    };
  }

  /// Resolves a [NetworkConnectionType] from a string identifier.
  static NetworkConnectionType fromCode(String? code) {
    switch (code?.trim().toLowerCase()) {
      case 'wifi':
        return NetworkConnectionType.wifi;
      case 'ethernet':
        return NetworkConnectionType.ethernet;
      case 'cellular':
        return NetworkConnectionType.cellular;
      case 'vpn':
        return NetworkConnectionType.vpn;
      case 'loopback':
        return NetworkConnectionType.loopback;
      case 'none':
        return NetworkConnectionType.none;
      default:
        return NetworkConnectionType.unknown;
    }
  }
}

/// Physical medium classification of the primary storage volume.
enum StorageMediumType {
  /// Solid-state drive (`ssd`).
  ssd('ssd'),

  /// Rotational hard disk drive (`hdd`).
  hdd('hdd'),

  /// Embedded mobile flash storage (`internal`).
  internal('internal'),

  /// NVMe solid-state storage (`nvme`).
  nvme('nvme'),

  /// Virtual or RAM-backed storage volume (`virtual`).
  virtual('virtual'),

  /// Storage medium type could not be determined (`unknown`).
  unknown('unknown');

  const StorageMediumType(this.code);

  /// Canonical string code.
  final String code;

  /// Converts a Pigeon-generated [WireStorageMediumType] into [StorageMediumType].
  static StorageMediumType fromPigeon(WireStorageMediumType type) {
    return switch (type) {
      WireStorageMediumType.ssd => StorageMediumType.ssd,
      WireStorageMediumType.hdd => StorageMediumType.hdd,
      WireStorageMediumType.internalStorage => StorageMediumType.internal,
      WireStorageMediumType.nvme => StorageMediumType.nvme,
      WireStorageMediumType.virtualDisk => StorageMediumType.virtual,
      WireStorageMediumType.unknown => StorageMediumType.unknown,
    };
  }

  /// Converts this domain [StorageMediumType] into a Pigeon [WireStorageMediumType].
  WireStorageMediumType toPigeon() {
    return switch (this) {
      StorageMediumType.ssd => WireStorageMediumType.ssd,
      StorageMediumType.hdd => WireStorageMediumType.hdd,
      StorageMediumType.internal => WireStorageMediumType.internalStorage,
      StorageMediumType.nvme => WireStorageMediumType.nvme,
      StorageMediumType.virtual => WireStorageMediumType.virtualDisk,
      StorageMediumType.unknown => WireStorageMediumType.unknown,
    };
  }

  /// Resolves a [StorageMediumType] from a string label.
  static StorageMediumType fromCode(String? code) {
    switch (code?.trim().toLowerCase()) {
      case 'ssd':
        return StorageMediumType.ssd;
      case 'hdd':
        return StorageMediumType.hdd;
      case 'internal':
        return StorageMediumType.internal;
      case 'nvme':
        return StorageMediumType.nvme;
      case 'virtual':
        return StorageMediumType.virtual;
      default:
        return StorageMediumType.unknown;
    }
  }
}
