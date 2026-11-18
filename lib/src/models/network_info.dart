import 'package:flutter/foundation.dart';

import '../messages.g.dart';
import 'device_enums.dart';

/// Immutable snapshot of active network connectivity, transport type, and interface addresses.
@immutable
class NetworkInfo {
  const NetworkInfo({
    this.ipAddress,
    NetworkConnectionType? connectionType,
    String? networkType,
    this.macAddress,
    this.interfaceName,
  }) : connectionType =
           connectionType ??
           (networkType == 'wifi'
               ? NetworkConnectionType.wifi
               : networkType == 'ethernet'
               ? NetworkConnectionType.ethernet
               : networkType == 'cellular'
               ? NetworkConnectionType.cellular
               : networkType == 'vpn'
               ? NetworkConnectionType.vpn
               : networkType == 'loopback'
               ? NetworkConnectionType.loopback
               : networkType == 'none'
               ? NetworkConnectionType.none
               : NetworkConnectionType.unknown),
       networkType =
           networkType ??
           (connectionType == NetworkConnectionType.wifi
               ? 'wifi'
               : connectionType == NetworkConnectionType.ethernet
               ? 'ethernet'
               : connectionType == NetworkConnectionType.cellular
               ? 'cellular'
               : connectionType == NetworkConnectionType.vpn
               ? 'vpn'
               : connectionType == NetworkConnectionType.loopback
               ? 'loopback'
               : connectionType == NetworkConnectionType.none
               ? 'none'
               : 'unknown');

  /// Creates a [NetworkInfo] domain model from a Pigeon [PigeonNetworkInfo] message.
  factory NetworkInfo.fromPigeon(PigeonNetworkInfo message) {
    final resolvedType =
        message.connectionType != PigeonNetworkConnectionType.unknown
        ? NetworkConnectionType.fromPigeon(message.connectionType)
        : NetworkConnectionType.fromCode(message.networkType);
    final rawType = message.networkType.trim();
    final canonicalType = rawType.isNotEmpty ? rawType : resolvedType.code;

    return NetworkInfo(
      ipAddress: _nonEmptyOrNull(message.ipAddress),
      connectionType: resolvedType,
      networkType: canonicalType,
      macAddress: _nonEmptyOrNull(message.macAddress),
      interfaceName: _nonEmptyOrNull(message.interfaceName),
    );
  }

  /// Active local IPv4 address when available, or `null`.
  final String? ipAddress;

  /// Strongly-typed network transport classification.
  final NetworkConnectionType connectionType;

  /// Canonical connection type code (`wifi`, `ethernet`, `cellular`, `none`, or `unknown`).
  final String networkType;

  /// Hardware MAC address in lowercase colon-hex format when available on desktop, or `null` on mobile.
  final String? macAddress;

  /// Active network adapter or BSD interface name (e.g. `en0`, `wlan0`, `eth0`) when available.
  final String? interfaceName;

  /// Whether the device currently has an active network connection.
  bool get isConnected =>
      connectionType != NetworkConnectionType.none && networkType != 'none';

  /// Whether the active transport is wireless (`wifi` or `cellular`).
  bool get isWireless =>
      connectionType == NetworkConnectionType.wifi ||
      connectionType == NetworkConnectionType.cellular;

  /// Returns a copy of this [NetworkInfo] with selectively overridden fields.
  NetworkInfo copyWith({
    String? ipAddress,
    NetworkConnectionType? connectionType,
    String? networkType,
    String? macAddress,
    String? interfaceName,
  }) {
    return NetworkInfo(
      ipAddress: ipAddress ?? this.ipAddress,
      connectionType: connectionType ?? this.connectionType,
      networkType: networkType ?? this.networkType,
      macAddress: macAddress ?? this.macAddress,
      interfaceName: interfaceName ?? this.interfaceName,
    );
  }

  /// Converts this [NetworkInfo] into a Pigeon [PigeonNetworkInfo] message.
  PigeonNetworkInfo toPigeon() {
    return PigeonNetworkInfo(
      ipAddress: ipAddress,
      connectionType: PigeonNetworkConnectionType.values.byName(
        connectionType.name,
      ),
      networkType: networkType,
      macAddress: macAddress,
      interfaceName: interfaceName,
    );
  }

  /// Serializes this [NetworkInfo] to a structured key-value map.
  Map<String, Object?> toMap() => <String, Object?>{
    'ipAddress': ipAddress,
    'connectionType': connectionType.code,
    'networkType': networkType,
    'macAddress': macAddress,
    'interfaceName': interfaceName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkInfo &&
          ipAddress == other.ipAddress &&
          connectionType == other.connectionType &&
          networkType == other.networkType &&
          macAddress == other.macAddress &&
          interfaceName == other.interfaceName;

  @override
  int get hashCode => Object.hash(
    ipAddress,
    connectionType,
    networkType,
    macAddress,
    interfaceName,
  );

  @override
  String toString() =>
      'NetworkInfo(ipAddress: $ipAddress, connectionType: ${connectionType.code}, '
      'networkType: $networkType, macAddress: $macAddress, '
      'interfaceName: $interfaceName)';

  static String? _nonEmptyOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
