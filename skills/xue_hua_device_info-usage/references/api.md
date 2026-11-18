# Public API reference (v2.1.0)

Source of truth: the Dart files under `lib/`.

App import:

```dart
import 'package:xue_hua_device_info/xue_hua_device_info.dart';
```

That library exports `XueHuaDeviceInfo`, the five modular domain models (`DeviceInfo`, `BatteryInfo`, `NetworkInfo`, `StorageInfo`, `DisplayInfo`), and the four domain enums (`BatteryChargingState`, `BatteryHealthStatus`, `NetworkConnectionType`, `StorageMediumType`).

---

## `XueHuaDeviceInfo`

Facade for the five independent native snapshots powered by **Pigeon (`^30.0.4`)** (`XueHuaDeviceInfoHostApi`). File: `lib/xue_hua_device_info.dart`.

### Static Methods

- `static Future<DeviceInfo> getDeviceInfo()`
- `static Future<BatteryInfo> getBatteryInfo()`
- `static Future<NetworkInfo> getNetworkInfo()`
- `static Future<StorageInfo> getStorageInfo()`
- `static Future<DisplayInfo> getDisplayInfo()`
- `@visibleForTesting static void setHostApiForTesting(XueHuaDeviceInfoHostApi? api)`

---

## Modular Domain Models (`lib/src/models/`)

1. **`DeviceInfo`** (`lib/src/models/device_info.dart`)
   - Fields: `deviceId`, `manufacturer`, `model`, `serial`, `name`, `operatingSystem`, `osVersion`, `architecture`
   - Computed: `displayTitle`, `hasSerial`
   - Methods: `copyWith(...)`, `toPigeon()`, `toMap()`, `==`, `hashCode`, `toString()`

2. **`BatteryInfo`** (`lib/src/models/battery_info.dart`)
   - Fields: `level`, `isCharging`, `chargingState` (`BatteryChargingState`), `healthStatus` (`BatteryHealthStatus`), `health`, `hasBattery`
   - Computed: `levelRatio`, `formattedLevel`
   - Methods: `copyWith(...)`, `toPigeon()`, `toMap()`, `==`, `hashCode`, `toString()`

3. **`NetworkInfo`** (`lib/src/models/network_info.dart`)
   - Fields: `ipAddress`, `connectionType` (`NetworkConnectionType`), `networkType`, `macAddress`, `interfaceName`
   - Computed: `isConnected`, `isWireless`
   - Methods: `copyWith(...)`, `toPigeon()`, `toMap()`, `==`, `hashCode`, `toString()`

4. **`StorageInfo`** (`lib/src/models/storage_info.dart`)
   - Fields: `totalBytes`, `freeBytes`, `mediumType` (`StorageMediumType`), `storageType`
   - Computed: `usedBytes`, `usageRatio`, `usedPercentage`, `totalGigabytes`, `freeGigabytes`, `usedGigabytes`
   - Methods: `copyWith(...)`, `toPigeon()`, `toMap()`, `==`, `hashCode`, `toString()`

5. **`DisplayInfo`** (`lib/src/models/display_info.dart`)
   - Fields: `width`, `height`, `scaleFactor`, `refreshRate`
   - Computed: `logicalWidth`, `logicalHeight`, `aspectRatio`, `physicalResolution`, `logicalResolution`, `isHighRefreshRate`
   - Methods: `copyWith(...)`, `toPigeon()`, `toMap()`, `==`, `hashCode`, `toString()`
