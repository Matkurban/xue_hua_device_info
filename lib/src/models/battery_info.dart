import 'package:flutter/foundation.dart';

import '../messages.g.dart';
import 'device_enums.dart';
import 'model_utils.dart';

/// Immutable snapshot of battery charge level, charging state, and health status.
@immutable
class BatteryInfo {
  const BatteryInfo({
    this.level,
    this.isCharging,
    BatteryChargingState? chargingState,
    BatteryHealthStatus? healthStatus,
    this.health,
    bool? hasBattery,
  }) : chargingState =
           chargingState ??
           (isCharging == true
               ? BatteryChargingState.charging
               : isCharging == false
               ? BatteryChargingState.discharging
               : BatteryChargingState.unknown),
       healthStatus = healthStatus ?? BatteryHealthStatus.unknown,
       hasBattery = hasBattery ?? (level != null || isCharging != null);

  /// Creates a [BatteryInfo] domain model from a Pigeon [WireBatteryInfo] message.
  factory BatteryInfo.fromPigeon(WireBatteryInfo message) {
    final normalizedLevel = message.level != null &&
            message.level! >= 0.0 &&
            message.level! <= 100.0
        ? message.level
        : null;
    final cleanHealth = nonEmptyOrNull(message.health);
    final resolvedHealthStatus =
        message.healthStatus != WireBatteryHealthStatus.unknown
        ? BatteryHealthStatus.fromPigeon(message.healthStatus)
        : BatteryHealthStatus.fromLabel(cleanHealth);
    final resolvedChargingState =
        message.chargingState != WireBatteryChargingState.unknown
        ? BatteryChargingState.fromPigeon(message.chargingState)
        : BatteryChargingState.fromCode(null, isCharging: message.isCharging);

    return BatteryInfo(
      level: normalizedLevel,
      isCharging: message.isCharging,
      chargingState: resolvedChargingState,
      healthStatus: resolvedHealthStatus,
      health: cleanHealth,
      hasBattery: message.hasBattery || normalizedLevel != null,
    );
  }

  /// Charge level in percent (`0.0`–`100.0`), or `null` when unavailable.
  final double? level;

  /// Whether the battery is actively charging (platform semantics may vary when full),
  /// or `null` when unavailable.
  final bool? isCharging;

  /// Strongly-typed charging state classification.
  final BatteryChargingState chargingState;

  /// Strongly-typed battery health status classification.
  final BatteryHealthStatus healthStatus;

  /// Platform-reported battery health string when available, or `null`.
  final String? health;

  /// Whether the host machine has a detectable system battery.
  final bool hasBattery;

  /// Charge level normalized to `0.0`–`1.0`, or `null` when [level] is unavailable.
  double? get levelRatio =>
      level == null ? null : (level! / 100.0).clamp(0.0, 1.0);

  /// Human-readable battery level percentage string (e.g. `"85.0%"` or `"N/A"`).
  String get formattedLevel =>
      level == null ? 'N/A' : '${level!.toStringAsFixed(1)}%';

  /// Returns a copy of this [BatteryInfo] with selectively overridden fields.
  ///
  /// Pass any `clear*` flag as `true` to explicitly reset a nullable field to `null`.
  BatteryInfo copyWith({
    double? level,
    bool clearLevel = false,
    bool? isCharging,
    bool clearIsCharging = false,
    BatteryChargingState? chargingState,
    BatteryHealthStatus? healthStatus,
    String? health,
    bool clearHealth = false,
    bool? hasBattery,
  }) {
    return BatteryInfo(
      level: clearLevel ? null : (level ?? this.level),
      isCharging: clearIsCharging ? null : (isCharging ?? this.isCharging),
      chargingState: chargingState ?? this.chargingState,
      healthStatus: healthStatus ?? this.healthStatus,
      health: clearHealth ? null : (health ?? this.health),
      hasBattery: hasBattery ?? this.hasBattery,
    );
  }

  /// Converts this [BatteryInfo] into a Pigeon [WireBatteryInfo] message.
  WireBatteryInfo toPigeon() {
    return WireBatteryInfo(
      level: level,
      isCharging: isCharging,
      chargingState: chargingState.toPigeon(),
      healthStatus: healthStatus.toPigeon(),
      health: health,
      hasBattery: hasBattery,
    );
  }

  /// Serializes this [BatteryInfo] to a structured key-value map.
  Map<String, Object?> toMap() => <String, Object?>{
    'level': level,
    'isCharging': isCharging,
    'chargingState': chargingState.code,
    'healthStatus': healthStatus.code,
    'health': health,
    'hasBattery': hasBattery,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryInfo &&
          level == other.level &&
          isCharging == other.isCharging &&
          chargingState == other.chargingState &&
          healthStatus == other.healthStatus &&
          health == other.health &&
          hasBattery == other.hasBattery;

  @override
  int get hashCode => Object.hash(
    level,
    isCharging,
    chargingState,
    healthStatus,
    health,
    hasBattery,
  );

  @override
  String toString() =>
      'BatteryInfo(level: $level, isCharging: $isCharging, '
      'chargingState: ${chargingState.code}, healthStatus: ${healthStatus.code}, '
      'health: $health, hasBattery: $hasBattery)';
}
