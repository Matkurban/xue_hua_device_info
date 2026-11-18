import 'package:flutter/foundation.dart';

import '../messages.g.dart';

/// Immutable snapshot of the primary display's physical resolution, density scale, and refresh rate.
@immutable
class DisplayInfo {
  const DisplayInfo({
    required this.width,
    required this.height,
    required this.scaleFactor,
    this.refreshRate,
  });

  /// Creates a [DisplayInfo] domain model from a Pigeon [WireDisplayInfo] message.
  factory DisplayInfo.fromPigeon(WireDisplayInfo message) {
    return DisplayInfo(
      width: message.width < 0 ? 0 : message.width,
      height: message.height < 0 ? 0 : message.height,
      scaleFactor: message.scaleFactor <= 0 ? 1.0 : message.scaleFactor,
      refreshRate: message.refreshRate != null && message.refreshRate! > 0
          ? message.refreshRate
          : null,
    );
  }

  /// Physical width in pixels.
  final int width;

  /// Physical height in pixels.
  final int height;

  /// Logical-to-physical pixel density scale factor.
  final double scaleFactor;

  /// Display refresh rate in Hz when available, or `null`.
  final double? refreshRate;

  /// Logical width in points (`width / scaleFactor`).
  double get logicalWidth =>
      scaleFactor > 0 ? width / scaleFactor : width.toDouble();

  /// Logical height in points (`height / scaleFactor`).
  double get logicalHeight =>
      scaleFactor > 0 ? height / scaleFactor : height.toDouble();

  /// Display aspect ratio (`width / height`), or `0.0` when height is zero.
  double get aspectRatio => height > 0 ? width / height : 0.0;

  /// Formatted physical resolution string (e.g. `"2560x1440"`).
  String get physicalResolution => '${width}x$height';

  /// Formatted logical resolution string (e.g. `"1280x720"`).
  String get logicalResolution =>
      '${logicalWidth.round()}x${logicalHeight.round()}';

  /// Whether the display operates above standard 60 Hz (`> 60.5 Hz`).
  bool get isHighRefreshRate => (refreshRate ?? 60.0) > 60.5;

  /// Returns a copy of this [DisplayInfo] with selectively overridden fields.
  ///
  /// Pass `clearRefreshRate: true` to explicitly reset [refreshRate] to `null`.
  DisplayInfo copyWith({
    int? width,
    int? height,
    double? scaleFactor,
    double? refreshRate,
    bool clearRefreshRate = false,
  }) {
    return DisplayInfo(
      width: width ?? this.width,
      height: height ?? this.height,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      refreshRate: clearRefreshRate ? null : (refreshRate ?? this.refreshRate),
    );
  }

  /// Converts this [DisplayInfo] into a Pigeon [WireDisplayInfo] message.
  WireDisplayInfo toPigeon() {
    return WireDisplayInfo(
      width: width,
      height: height,
      scaleFactor: scaleFactor,
      refreshRate: refreshRate,
    );
  }

  /// Serializes this [DisplayInfo] to a structured key-value map.
  Map<String, Object?> toMap() => <String, Object?>{
    'width': width,
    'height': height,
    'scaleFactor': scaleFactor,
    'refreshRate': refreshRate,
    'logicalWidth': logicalWidth,
    'logicalHeight': logicalHeight,
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
      'DisplayInfo(width: $width, height: $height, '
      'scaleFactor: $scaleFactor, refreshRate: $refreshRate)';
}
