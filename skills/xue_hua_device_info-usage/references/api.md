# Public API reference

Source of truth: the Dart files under `lib/`. Signatures below match those files. Do not add methods, named parameters, or types that are not listed here.

App import:

```dart
import 'package:xue_hua_device_info/xue_hua_device_info.dart';
```

That library exports `XueHuaDeviceInfo` and the five models from `src/models.dart`. It does **not** export `XueHuaDeviceInfoPlatform` or `MethodChannelXueHuaDeviceInfo`.

Plugin-implementer imports (tests / federated plugins only):

```dart
import 'package:xue_hua_device_info/xue_hua_device_info_platform_interface.dart';
import 'package:xue_hua_device_info/xue_hua_device_info_method_channel.dart';
```

Not public API (do not call or document as package methods): `_asString`, `_asBool`, `_asDouble`, `_requireInt`, `_requireDouble`, `_requireMap`, `_token`, and any Kotlin / Swift / C++ helper.

---

## `XueHuaDeviceInfo`

Facade for the five native snapshots. File: `lib/xue_hua_device_info.dart`.

There is no public constructor. The only constructor is:

```dart
const XueHuaDeviceInfo._();
```

That constructor is library-private. App code cannot instantiate this class. There is no `instance` on `XueHuaDeviceInfo` itself. There is no `initialize()`.

Each static method has **no parameters**. Each delegates to `XueHuaDeviceInfoPlatform.instance` of the same name. Each may complete with a model or throw (see Exceptions).

### `static Future<DeviceInfo> getDeviceInfo()`

Returns device identity and hardware descriptors. Native method name: `getDeviceInfo`.

### `static Future<BatteryInfo> getBatteryInfo()`

Returns battery level, charging flag, and optional health. Native method name: `getBatteryInfo`.

### `static Future<NetworkInfo> getNetworkInfo()`

Returns local IPv4, connection type, and optional MAC. Native method name: `getNetworkInfo`.

### `static Future<StorageInfo> getStorageInfo()`

Returns primary-volume capacity in bytes. Native method name: `getStorageInfo`.

### `static Future<DisplayInfo> getDisplayInfo()`

Returns primary-display physical size, scale, and optional refresh rate. Native method name: `getDisplayInfo`.

### Exceptions thrown by the five methods

These methods do not declare a custom exception type. Failures surface as:

| Thrown type                                     | When                                                                                                                                                                                                |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PlatformException` with `code: 'native_error'` | Android native handler caught an exception. `message` is the Java/Kotlin exception message. `details` is `null`.                                                                                    |
| `PlatformException` with `code: 'bad_response'` | Host returned a non-`Map`, or a map whose field types failed model decoding.                                                                                                                        |
| `MissingPluginException`                        | No handler registered (Web, or plugin not linked).                                                                                                                                                  |
| Other `PlatformException`                       | Host used Flutter `result.error` / equivalent. iOS, macOS, Windows, and Linux handlers do not wrap unexpected native failures in `native_error`; they succeed with a map or return not-implemented. |

Default `XueHuaDeviceInfoPlatform` method bodies throw `UnimplementedError` if a custom platform instance did not override them. The default instance is `MethodChannelXueHuaDeviceInfo`, which does override all five.

---

## Shared model behavior

`DeviceInfo`, `BatteryInfo`, `NetworkInfo`, `StorageInfo`, and `DisplayInfo` each implement:

- a `const` generative constructor
- `factory … fromMap(Map<Object?, Object?> map)`
- `Map<String, Object?> toMap()`
- `operator ==` / `hashCode` (value equality: `identical` or all documented fields equal)
- `toString()` (format `ClassName(field: value, …)` in field declaration order)

They are not `enum`s, not `sealed`, and have no `copyWith`, `toJson`, or `fromJson`. Map keys are the Dart field names (camelCase). Extra keys in `fromMap` are ignored. Missing optional keys decode as `null`.

### `fromMap` type rules

These rules are enforced by private helpers. Treat them as part of `fromMap` behavior, not as public functions.

| Dart field kind   | Accepted values                             | Otherwise                                                                |
| ----------------- | ------------------------------------------- | ------------------------------------------------------------------------ |
| `String?`         | `null` or `String`                          | `PlatformException(code: 'bad_response')` — e.g. an `int` for `deviceId` |
| `bool?`           | `null` or `bool`                            | same (`bad_response`)                                                    |
| `double?`         | `null` or `num` (widened with `toDouble()`) | same (`bad_response`)                                                    |
| required `int`    | `num` (`toInt()`). `null` is invalid        | same (`bad_response`)                                                    |
| required `double` | `num` (`toDouble()`). `null` is invalid     | same (`bad_response`)                                                    |

`fromMap` rethrows an existing `PlatformException` and wraps any other decode error as `PlatformException(code: 'bad_response', message: 'Invalid <Class> payload: …')`.

`toMap()` always includes every field key, including keys whose value is `null`.

---

## `DeviceInfo`

Identity and hardware descriptors. Missing values are `null`. iOS does not expose a hardware serial via public APIs.

### Fields

| Field          | Type      | Meaning                                                                                                                                                                                       |
| -------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `deviceId`     | `String?` | Platform durable id (Android ID, IDFV, machine UUID, or similar).                                                                                                                             |
| `manufacturer` | `String?` | Manufacturer when the host supplies one.                                                                                                                                                      |
| `model`        | `String?` | Model / machine identifier when available.                                                                                                                                                    |
| `serial`       | `String?` | Hardware serial when the host supplies one. Always `null` on Android and iOS.                                                                                                                 |
| `name`         | `String?` | User-visible device or host name. On iOS 16+ without the `com.apple.developer.device-information.user-assigned-device-name` entitlement this is typically a generic label such as `"iPhone"`. |

### `const DeviceInfo({String? deviceId, String? manufacturer, String? model, String? serial, String? name})`

All parameters named and optional. All default to `null`.

### `factory DeviceInfo.fromMap(Map<Object?, Object?> map)`

Reads `deviceId`, `manufacturer`, `model`, `serial`, `name` with the `String?` rule. None of these keys is required.

### `Map<String, Object?> toMap()`

Keys: `deviceId`, `manufacturer`, `model`, `serial`, `name`.

### `bool operator ==(Object other)`

True if `identical`, or `other` is `DeviceInfo` and all five fields are `==`.

### `int get hashCode`

`Object.hash(deviceId, manufacturer, model, serial, name)`.

### `String toString()`

`DeviceInfo(deviceId: …, manufacturer: …, model: …, serial: …, name: …)`.

---

## `BatteryInfo`

Battery snapshot.

### Fields

| Field        | Type      | Meaning                                                                                           |
| ------------ | --------- | ------------------------------------------------------------------------------------------------- |
| `level`      | `double?` | Charge percent in `0`–`100`, or `null` if unavailable / out of range on the host.                 |
| `isCharging` | `bool?`   | Charging (or treated as charging) when the host can tell; `null` if unavailable.                  |
| `health`     | `String?` | Host health label. Android uses a fixed set (see platform-behavior). Other platforms send `null`. |

### `const BatteryInfo({double? level, bool? isCharging, String? health})`

All parameters named and optional.

### `factory BatteryInfo.fromMap(Map<Object?, Object?> map)`

- `level`: `double?` rule (`num` allowed, e.g. native `50` becomes `50.0`)
- `isCharging`: `bool?` rule
- `health`: `String?` rule

### `Map<String, Object?> toMap()`

Keys: `level`, `isCharging`, `health`.

### `bool operator ==(Object other)`

Value equality on `level`, `isCharging`, `health`.

### `int get hashCode`

`Object.hash(level, isCharging, health)`.

### `String toString()`

`BatteryInfo(level: …, isCharging: …, health: …)`.

---

## `NetworkInfo`

Local IPv4 and connection kind.

### Fields

| Field         | Type      | Meaning                                                                      |
| ------------- | --------- | ---------------------------------------------------------------------------- |
| `ipAddress`   | `String?` | First non-loopback IPv4 the host reports, or `null`.                         |
| `networkType` | `String?` | `wifi`, `ethernet`, `cellular`, `none`, or `unknown` when the host fills it. |
| `macAddress`  | `String?` | MAC when the host reports one. Always `null` on Android and iOS.             |

There is no IPv6 field, no SSID, no VPN flag, and no DNS field.

### `const NetworkInfo({String? ipAddress, String? networkType, String? macAddress})`

All parameters named and optional.

### `factory NetworkInfo.fromMap(Map<Object?, Object?> map)`

All three keys use the `String?` rule.

### `Map<String, Object?> toMap()`

Keys: `ipAddress`, `networkType`, `macAddress`.

### `bool operator ==(Object other)`

Value equality on the three fields.

### `int get hashCode`

`Object.hash(ipAddress, networkType, macAddress)`.

### `String toString()`

`NetworkInfo(ipAddress: …, networkType: …, macAddress: …)`.

---

## `StorageInfo`

Primary storage capacity. `totalBytes` and `freeBytes` are required non-nullable `int`s.

### Fields

| Field         | Type      | Meaning                                                                                        |
| ------------- | --------- | ---------------------------------------------------------------------------------------------- |
| `totalBytes`  | `int`     | Total capacity in bytes. Hosts may send `0` on failure.                                        |
| `freeBytes`   | `int`     | Free / available bytes (host-defined “available”). Hosts may send `0` on failure.              |
| `storageType` | `String?` | Kind when the host supplies one. Android and iOS send `"internal"`. Desktop hosts send `null`. |

There is no `usedBytes` getter.

### `const StorageInfo({required int totalBytes, required int freeBytes, String? storageType})`

`totalBytes` and `freeBytes` are required named parameters. `storageType` is optional.

### `factory StorageInfo.fromMap(Map<Object?, Object?> map)`

- `totalBytes`: required `int` rule
- `freeBytes`: required `int` rule
- `storageType`: `String?` rule

A missing or non-`num` `totalBytes` / `freeBytes` throws `PlatformException(code: 'bad_response')`.

### `Map<String, Object?> toMap()`

Keys: `totalBytes`, `freeBytes`, `storageType`.

### `bool operator ==(Object other)`

Value equality on the three fields.

### `int get hashCode`

`Object.hash(totalBytes, freeBytes, storageType)`.

### `String toString()`

`StorageInfo(totalBytes: …, freeBytes: …, storageType: …)`.

---

## `DisplayInfo`

Primary display. `width`, `height`, and `scaleFactor` are required.

### Fields

| Field         | Type      | Meaning                                                                         |
| ------------- | --------- | ------------------------------------------------------------------------------- |
| `width`       | `int`     | Physical width in pixels.                                                       |
| `height`      | `int`     | Physical height in pixels.                                                      |
| `scaleFactor` | `double`  | Logical-to-physical scale (density / backing scale / DPI÷96 depending on host). |
| `refreshRate` | `double?` | Refresh rate in Hz when the host can measure it.                                |

There is no `orientation`, `safeArea`, or multi-display API. This is the primary / default display only.

### `const DisplayInfo({required int width, required int height, required double scaleFactor, double? refreshRate})`

`width`, `height`, and `scaleFactor` are required named parameters. `refreshRate` is optional.

### `factory DisplayInfo.fromMap(Map<Object?, Object?> map)`

- `width`: required `int` rule
- `height`: required `int` rule
- `scaleFactor`: required `double` rule (`num` allowed)
- `refreshRate`: `double?` rule

### `Map<String, Object?> toMap()`

Keys: `width`, `height`, `scaleFactor`, `refreshRate`.

### `bool operator ==(Object other)`

Value equality on the four fields.

### `int get hashCode`

`Object.hash(width, height, scaleFactor, refreshRate)`.

### `String toString()`

`DisplayInfo(width: …, height: …, scaleFactor: …, refreshRate: …)`.

---

## Plugin implementer API (do not use from app widgets)

### `XueHuaDeviceInfoPlatform`

Abstract class extending `plugin_platform_interface.PlatformInterface`. File: `lib/xue_hua_device_info_platform_interface.dart`.

#### `XueHuaDeviceInfoPlatform()`

Public generative constructor. Passes a private token to `PlatformInterface`. Custom implementations must extend this class (not implement it) so `verifyToken` succeeds.

#### `static XueHuaDeviceInfoPlatform get instance`

Current platform implementation. Default: a `MethodChannelXueHuaDeviceInfo()`.

#### `static set instance(XueHuaDeviceInfoPlatform instance)`

Replaces the instance after `PlatformInterface.verifyToken(instance, token)`. Passing a class that does not extend `XueHuaDeviceInfoPlatform` (or used the wrong token) fails verification. Tests typically assign a mock that uses `MockPlatformInterfaceMixin`.

#### `Future<DeviceInfo> getDeviceInfo()`

Default body: `throw UnimplementedError('getDeviceInfo() has not been implemented.');`

#### `Future<BatteryInfo> getBatteryInfo()`

Default body: `throw UnimplementedError('getBatteryInfo() has not been implemented.');`

#### `Future<NetworkInfo> getNetworkInfo()`

Default body: `throw UnimplementedError('getNetworkInfo() has not been implemented.');`

#### `Future<StorageInfo> getStorageInfo()`

Default body: `throw UnimplementedError('getStorageInfo() has not been implemented.');`

#### `Future<DisplayInfo> getDisplayInfo()`

Default body: `throw UnimplementedError('getDisplayInfo() has not been implemented.');`

Overrides must keep these exact signatures (no extra parameters).

### `MethodChannelXueHuaDeviceInfo`

Default host implementation. File: `lib/xue_hua_device_info_method_channel.dart`. Extends `XueHuaDeviceInfoPlatform`.

#### `final MethodChannel methodChannel`

Value: `const MethodChannel('xue_hua_device_info')`. Annotated `@visibleForTesting`. App code must not depend on this field.

Channel method names (exact strings): `getDeviceInfo`, `getBatteryInfo`, `getNetworkInfo`, `getStorageInfo`, `getDisplayInfo`.

#### Overrides

Each override:

1. `invokeMethod<Object?>` with the matching method name (no arguments).
2. Requires the result to be a `Map`; otherwise `PlatformException(code: 'bad_response', message: '<method> returned an unexpected response: …')`.
3. Decodes with the matching `fromMap`.
4. Rethrows `PlatformException`; wraps other decode errors as `PlatformException(code: 'bad_response', message: '<method> decode failed: …')`.

| Method                                 | Decode                |
| -------------------------------------- | --------------------- |
| `Future<DeviceInfo> getDeviceInfo()`   | `DeviceInfo.fromMap`  |
| `Future<BatteryInfo> getBatteryInfo()` | `BatteryInfo.fromMap` |
| `Future<NetworkInfo> getNetworkInfo()` | `NetworkInfo.fromMap` |
| `Future<StorageInfo> getStorageInfo()` | `StorageInfo.fromMap` |
| `Future<DisplayInfo> getDisplayInfo()` | `DisplayInfo.fromMap` |

---

## Removed or never-existed APIs (do not generate)

- `initialize()`, `init()`, `dispose()` on `XueHuaDeviceInfo`
- Public `XueHuaDeviceInfo()` constructor or singleton `.instance` on the facade
- Instance methods on `XueHuaDeviceInfo` (all five getters are `static`)
- Web implementation
- Rust / `flutter_rust_bridge` / Cargokit types from 1.x
- iOS Keychain UUID used as `serial` (removed in 2.0.0)
- `fromJson` / `toJson` / `copyWith` on models
- Extra snapshots (CPU, memory, sensors, locale, IMEI, advertising id)
