import 'package:flutter/foundation.dart';

import '../messages.g.dart';
import 'device_enums.dart';

/// Immutable snapshot of primary storage capacity, usage metrics, and medium classification.
@immutable
class StorageInfo {
  const StorageInfo({
    required this.totalBytes,
    required this.freeBytes,
    StorageMediumType? mediumType,
    this.storageType,
  }) : mediumType =
           mediumType ??
           (storageType == 'ssd'
               ? StorageMediumType.ssd
               : storageType == 'hdd'
               ? StorageMediumType.hdd
               : storageType == 'internal'
               ? StorageMediumType.internal
               : storageType == 'nvme'
               ? StorageMediumType.nvme
               : storageType == 'virtual'
               ? StorageMediumType.virtual
               : StorageMediumType.unknown);

  /// Creates a [StorageInfo] domain model from a Pigeon [PigeonStorageInfo] message.
  factory StorageInfo.fromPigeon(PigeonStorageInfo message) {
    final cleanStorageType = _nonEmptyOrNull(message.storageType);
    final resolvedMedium = message.mediumType != PigeonStorageMediumType.unknown
        ? StorageMediumType.fromPigeon(message.mediumType)
        : StorageMediumType.fromCode(cleanStorageType);
    final canonicalStorageType =
        cleanStorageType ??
        (resolvedMedium == StorageMediumType.unknown
            ? null
            : resolvedMedium.code);

    return StorageInfo(
      totalBytes: message.totalBytes < 0 ? 0 : message.totalBytes,
      freeBytes: message.freeBytes < 0 ? 0 : message.freeBytes,
      mediumType: resolvedMedium,
      storageType: canonicalStorageType,
    );
  }

  static const double _bytesPerGigabyte = 1024.0 * 1024.0 * 1024.0;

  /// Total capacity of the primary volume in bytes.
  final int totalBytes;

  /// Available free space on the primary volume in bytes.
  final int freeBytes;

  /// Strongly-typed physical medium classification.
  final StorageMediumType mediumType;

  /// Storage medium label (`ssd`, `hdd`, `internal`), or `null` when unknown.
  final String? storageType;

  /// Used space in bytes (`totalBytes - freeBytes`, clamped to `[0, totalBytes]`).
  int get usedBytes {
    if (totalBytes <= 0) return 0;
    final used = totalBytes - freeBytes;
    if (used < 0) return 0;
    if (used > totalBytes) return totalBytes;
    return used;
  }

  /// Fraction of total capacity currently in use (`0.0`–`1.0`).
  double get usageRatio {
    if (totalBytes <= 0) return 0.0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Percentage of total capacity currently in use (`0.0`–`100.0`).
  double get usedPercentage => usageRatio * 100.0;

  /// Total capacity in GiB (`bytes / 1024^3`).
  double get totalGigabytes => totalBytes / _bytesPerGigabyte;

  /// Free capacity in GiB (`bytes / 1024^3`).
  double get freeGigabytes => freeBytes / _bytesPerGigabyte;

  /// Used capacity in GiB (`bytes / 1024^3`).
  double get usedGigabytes => usedBytes / _bytesPerGigabyte;

  /// Returns a copy of this [StorageInfo] with selectively overridden fields.
  StorageInfo copyWith({
    int? totalBytes,
    int? freeBytes,
    StorageMediumType? mediumType,
    String? storageType,
  }) {
    return StorageInfo(
      totalBytes: totalBytes ?? this.totalBytes,
      freeBytes: freeBytes ?? this.freeBytes,
      mediumType: mediumType ?? this.mediumType,
      storageType: storageType ?? this.storageType,
    );
  }

  /// Converts this [StorageInfo] into a Pigeon [PigeonStorageInfo] message.
  PigeonStorageInfo toPigeon() {
    final pigeonMedium = switch (mediumType) {
      StorageMediumType.ssd => PigeonStorageMediumType.ssd,
      StorageMediumType.hdd => PigeonStorageMediumType.hdd,
      StorageMediumType.internal => PigeonStorageMediumType.internalStorage,
      StorageMediumType.nvme => PigeonStorageMediumType.nvme,
      StorageMediumType.virtual => PigeonStorageMediumType.virtualDisk,
      StorageMediumType.unknown => PigeonStorageMediumType.unknown,
    };
    return PigeonStorageInfo(
      totalBytes: totalBytes,
      freeBytes: freeBytes,
      mediumType: pigeonMedium,
      storageType: storageType,
    );
  }

  /// Serializes this [StorageInfo] to a structured key-value map.
  Map<String, Object?> toMap() => <String, Object?>{
    'totalBytes': totalBytes,
    'freeBytes': freeBytes,
    'usedBytes': usedBytes,
    'mediumType': mediumType.code,
    'storageType': storageType,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageInfo &&
          totalBytes == other.totalBytes &&
          freeBytes == other.freeBytes &&
          mediumType == other.mediumType &&
          storageType == other.storageType;

  @override
  int get hashCode =>
      Object.hash(totalBytes, freeBytes, mediumType, storageType);

  @override
  String toString() =>
      'StorageInfo(totalBytes: $totalBytes, freeBytes: $freeBytes, '
      'usedBytes: $usedBytes, mediumType: ${mediumType.code}, '
      'storageType: $storageType)';

  static String? _nonEmptyOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
