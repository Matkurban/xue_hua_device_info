import 'package:flutter/foundation.dart';

import '../messages.g.dart';
import 'device_enums.dart';
import 'model_utils.dart';

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

  /// Creates a [NetworkInfo] domain model from a Pigeon [WireNetworkInfo] message.
  factory NetworkInfo.fromPigeon(WireNetworkInfo message) {
    final resolvedType =
        message.connectionType != WireNetworkConnectionType.unknown
        ? NetworkConnectionType.fromPigeon(message.connectionType)
        : NetworkConnectionType.fromCode(message.networkType);
    final rawType = message.networkType.trim();
    final canonicalType =
        rawType.isEmpty || rawType.toLowerCase() == 'unknown'
        ? resolvedType.code
        : rawType;

    return NetworkInfo(
      ipAddress: nonEmptyOrNull(message.ipAddress),
      connectionType: resolvedType,
      networkType: canonicalType,
      macAddress: nonEmptyOrNull(message.macAddress),
      interfaceName: nonEmptyOrNull(message.interfaceName),
    );
  }

  /// Active local IPv4 address when available, or `null`.
  final String? ipAddress;

  /// Strongly-typed network transport classification.
  final NetworkConnectionType connectionType;

  /// Canonical connection type code (`wifi`, `ethernet`, `cellular`, `vpn`, `loopback`, `none`, or `unknown`).
  final String networkType;

  /// Hardware MAC address in lowercase colon-hex format when available on desktop, or `null` on mobile.
  final String? macAddress;

  /// Active network adapter or BSD interface name (e.g. `en0`, `wlan0`, `eth0`) when available.
  final String? interfaceName;

  /// Whether the device currently has an active network connection.
  bool get isConnected =>
      connectionType != NetworkConnectionType.none &&
      networkType != 'none' &&
      (connectionType != NetworkConnectionType.unknown || ipAddress != null);

  /// Whether the active transport is wireless (`wifi` or `cellular`).
  bool get isWireless =>
      connectionType == NetworkConnectionType.wifi ||
      connectionType == NetworkConnectionType.cellular;

  /// Returns a copy of this [NetworkInfo] with selectively overridden fields.
  ///
  /// Pass any `clear*` flag as `true` to explicitly reset a nullable field to `null`.
  NetworkInfo copyWith({
    String? ipAddress,
    bool clearIpAddress = false,
    NetworkConnectionType? connectionType,
    String? networkType,
    String? macAddress,
    bool clearMacAddress = false,
    String? interfaceName,
    bool clearInterfaceName = false,
  }) {
    final nextConnectionType = connectionType ?? this.connectionType;
    final nextNetworkType =
        networkType ??
        (connectionType != null ? connectionType.code : this.networkType);
    return NetworkInfo(
      ipAddress: clearIpAddress ? null : (ipAddress ?? this.ipAddress),
      connectionType: nextConnectionType,
      networkType: nextNetworkType,
      macAddress: clearMacAddress ? null : (macAddress ?? this.macAddress),
      interfaceName:
          clearInterfaceName ? null : (interfaceName ?? this.interfaceName),
    );
  }

  /// Converts this [NetworkInfo] into a Pigeon [WireNetworkInfo] message.
  WireNetworkInfo toPigeon() {
    return WireNetworkInfo(
      ipAddress: ipAddress,
      connectionType: connectionType.toPigeon(),
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
}
