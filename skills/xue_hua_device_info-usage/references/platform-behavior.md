# Platform field behavior

Values below come from the current native plugins (Kotlin / Swift / C++). Do not invent extra keys. A Dart `null` means the host sent JSON-null / omitted a usable value.

Web is not a plugin target. Calling any getter on Web throws `MissingPluginException`.

`networkType` strings the hosts actually emit: `wifi`, `ethernet`, `cellular`, `none`, `unknown`.

---

## `DeviceInfo`

| Field          | Android                                                    | iOS                                                                                                                                    | macOS                                       | Windows                                                       | Linux                                                                                    |
| -------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `deviceId`     | `Settings.Secure.ANDROID_ID`                               | `UIDevice.identifierForVendor?.uuidString` (may be `null`)                                                                             | `IOPlatformUUID`                            | `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`            | `/sys/class/dmi/id/product_uuid`, else `/etc/machine-id`                                 |
| `manufacturer` | `Build.MANUFACTURER`                                       | always `"Apple"`                                                                                                                       | always `"Apple"`                            | BIOS `SystemManufacturer`, after OEM-placeholder sanitization | `/sys/class/dmi/id/sys_vendor` (`None` / `To be filled by O.E.M.` become empty → `null`) |
| `model`        | `Build.MODEL`                                              | `uname` `machine` (e.g. `iPhone15,2`); if empty, `UIDevice.model`                                                                      | IOKit `model` bytes, else `sysctl hw.model` | BIOS `SystemProductName`, sanitized                           | `/sys/class/dmi/id/product_name`                                                         |
| `serial`       | **always `null`**                                          | **always `null`**                                                                                                                      | `IOPlatformSerialNumber` when present       | BIOS `SystemSerialNumber`, sanitized                          | `/sys/class/dmi/id/product_serial`                                                       |
| `name`         | API 25+: `Settings.Global.DEVICE_NAME`, else `Build.MODEL` | `UIDevice.name` (iOS 16+ without `com.apple.developer.device-information.user-assigned-device-name` is typically `"iPhone"` / generic) | `Host.current().localizedName`              | `GetComputerNameW`                                            | `gethostname`                                                                            |

Windows sanitization drops (case-insensitive) `none`, `default string`, `to be filled by o.e.m.`, `system serial number`, `o.e.m.`, `oem`. Empty after trim becomes `null`.

Do not treat iOS `serial` as a Keychain UUID. That 1.x behavior was removed in 2.0.0.

---

## `BatteryInfo`

| Field        | Android                                                                                  | iOS                                                                                     | macOS                                                                      | Windows                                                                                                      | Linux                                                                              |
| ------------ | ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| `level`      | `BatteryManager.BATTERY_PROPERTY_CAPACITY` as `double` if in `0`–`100`; otherwise `null` | `UIDevice.batteryLevel * 100` after enabling monitoring; `null` when `batteryLevel < 0` | Present `InternalBattery` `Current Capacity` / `Max Capacity` × 100; `null` if no source | `BatteryLifePercent` as `double` unless `255` (unknown) or no battery (`BatteryFlag == 128`)                 | First `type=Battery` sysfs `capacity` in `0`–`100`; else `null`                    |
| `isCharging` | `true` if status is `CHARGING` or `FULL`                                                 | `true` for `.charging` / `.full`; `false` for `.unplugged`; `null` otherwise            | `kIOPSIsCharging` if a source exists; else `null`                          | `true` only if `BatteryFlag & 8` (`BATTERY_FLAG_CHARGING`). AC power with a full battery is **not** charging | `true` if sysfs `status` is `Charging` or `Full`; `null` when level is unavailable |
| `health`     | mapped string (below)                                                                    | **always `null`**                                                                       | `kIOPSBatteryHealthKey` (`Good`/`Fair`/`Poor`) when published; else `null` | **always `null`**                                                                                            | sysfs `health` when present; else `null`                                           |

Android `health` values only:

| Android extra                        | Dart `health`         |
| ------------------------------------ | --------------------- |
| `BATTERY_HEALTH_GOOD`                | `good`                |
| `BATTERY_HEALTH_OVERHEAT`            | `overheat`            |
| `BATTERY_HEALTH_DEAD`                | `dead`                |
| `BATTERY_HEALTH_OVER_VOLTAGE`        | `over_voltage`        |
| `BATTERY_HEALTH_UNSPECIFIED_FAILURE` | `unspecified_failure` |
| `BATTERY_HEALTH_COLD`                | `cold`                |
| anything else                        | `unknown`             |

iOS enables `isBatteryMonitoringEnabled` for the call and turns it off in `defer`.

Desktop machines without a battery typically return `level: null`, `isCharging: null`, `health: null`.

---

## `NetworkInfo`

| Field         | Android                                                                                                     | iOS                                                                                     | macOS                                                                                                                                                         | Windows                                                                                                                     | Linux                                                                                                            |
| ------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `ipAddress`   | First up, non-loopback `Inet4Address`                                                                       | IPv4 on `en0` / `en*` / `pdp_ip*`; prefers `en0` (or `pdp_ip*` when cellular); skips `127.*`, `169.254.*`, `198.18.0.0/15` | IPv4 from the single selected iface (see below); skips `127.*`, `169.254.*`, `198.18.0.0/15`                                                                  | IPv4 from the single selected adapter (see below); skips `127.*`, `169.254.*`, and `198.18.0.0/15`                           | Single selected iface; skips `127.*` / `169.254.*`                                                               |
| `networkType` | Active `NetworkCapabilities`: wifi / ethernet / cellular; no network → `none`; other transports → `unknown` | `NWPathMonitor`: unsatisfied → `none`; else wifi / wiredEthernet / cellular / `unknown` | From the same selected iface via `SCNetworkInterfaceGetInterfaceType` (`IEEE80211`→`wifi`, `Ethernet`→`ethernet`); else name heuristics; no iface → `none`   | From the same selected adapter: `IF_TYPE_IEEE80211` → `wifi`; `IF_TYPE_ETHERNET_CSMACD` → `ethernet`; else `unknown`/`none` | From the same selected iface (`wifi`/`ethernet`/`unknown`/`none`)                                                |
| `macAddress`  | **always `null`**                                                                                           | **always `null`**                                                                       | MAC of the same selected iface (6-byte, lowercase colon-hex); `null` if missing                                                                                | MAC of the same selected adapter (6-byte, lowercase colon-hex); `null` if missing                                           | MAC of the same selected iface                                                                                   |

Windows selects one adapter: physical default-route (`GetBestInterfaceEx`) preferred, then other physical Wi-Fi/Ethernet by `Ipv4Metric`, then virtual/tunnel last. Hyper-V / WSL / VPN / Meta Tunnel descriptions are treated as virtual.

macOS selects one interface: `SCDynamicStore` `PrimaryInterface` when it has a usable IPv4 and is not virtual (`utun`/`bridge`/…); otherwise the best physical `en*`/`eth*`. Virtual and fake-IP interfaces are skipped.

There is no IPv6, SSID, or BSSID field.

iOS starts `NWPathMonitor` at plugin registration. `getNetworkInfo` uses the last path (or `currentPath`).

---

## `StorageInfo`

| Field         | Android                                                                        | iOS                                                  | macOS                                                            | Windows                                                                           | Linux                                                |
| ------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `totalBytes`  | `StatFs` of `Environment.getDataDirectory()`: `blockCountLong * blockSizeLong` | `volumeTotalCapacity` of `NSHomeDirectory()`, or `0` | `volumeTotalCapacity` of `/`, or `0`                             | `GetDiskFreeSpaceExW` on the Windows-directory drive (else `C:\`); `0` on failure | `statvfs("/")` `f_blocks * f_frsize`; `0` on failure |
| `freeBytes`   | `availableBlocksLong * blockSizeLong`                                          | `volumeAvailableCapacityForImportantUsage`, or `0`   | important-usage capacity, else `volumeAvailableCapacity`, or `0` | caller-available bytes from `GetDiskFreeSpaceExW`; `0` on failure                 | `f_bavail * f_frsize`; `0` on failure                |
| `storageType` | `"internal"`                                                                   | `"internal"`                                         | `"ssd"` / `"hdd"` from IOKit Medium Type, else **`null`**        | `"ssd"` / `"hdd"` from seek-penalty IOCTL, else **`null`**                        | `"ssd"` / `"hdd"` from `queue/rotational`, else **`null`** |

These are primary-volume numbers, not a list of disks. On Linux, `storageType` may be `"ssd"` or `"hdd"` from `queue/rotational`. On Windows it may be `"ssd"` or `"hdd"` from `IOCTL_STORAGE_QUERY_PROPERTY` / `StorageDeviceSeekPenaltyProperty` (`IncursSeekPenalty`). On macOS it may be `"ssd"` or `"hdd"` from IOKit `Device Characteristics` → `Medium Type` via DiskArbitration. Battery `health` remains **`null`** on Windows (`GetSystemPowerStatus` has no health field) and on iOS (no public API).

---

## `DisplayInfo`

| Field              | Android                                                             | iOS                                                  | macOS                                                        | Windows                                                          | Linux                                                                                           |
| ------------------ | ------------------------------------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `width` / `height` | `DisplayMetrics` from deprecated `getRealMetrics` (physical pixels) | `UIScreen.main.bounds` × `scale`, truncated to `int` | `CGDisplayMode.pixelWidth` / `pixelHeight` (Retina physical); else `CGDisplayPixelsWide` / `High` | `SM_CXSCREEN` / `SM_CYSCREEN`                                    | GDK primary (or first) monitor geometry × `gdk_monitor_get_scale_factor` (device pixels) |
| `scaleFactor`      | `DisplayMetrics.density` as `double`                                | `UIScreen.main.scale` as `double`                    | `NSScreen.main.backingScaleFactor`, or `1.0`                 | `LOGPIXELSX / 96.0` (1.0 if no DC)                               | GDK primary/first `gdk_monitor_get_scale_factor`, or `1.0`                                      |
| `refreshRate`      | default display `refreshRate` as `double`                           | `UIScreen.maximumFramesPerSecond` as `double`        | `CGDisplayMode.refreshRate` if `> 0`; else `NSScreen.maximumFramesPerSecond` (macOS 12+) | `EnumDisplaySettings` `dmDisplayFrequency` if `> 1`; else `null` | `gdk_monitor_get_refresh_rate` (millihertz → Hz) when `> 0`; else `null`                         |

Linux uses GDK only. Width/height can be `0` if no display/monitor is available (e.g. truly headless). `refreshRate` is `null` when GDK reports 0 millihertz.

This is the primary display only.

---

## Native errors and channel

Channel name: `xue_hua_device_info`.

Unknown method names: Android `result.notImplemented()`; iOS/macOS `FlutterMethodNotImplemented`; Windows `NotImplemented`; Linux `fl_method_not_implemented_response_new`. Dart then sees `MissingPluginException` (or the Flutter not-implemented equivalent), not a model.

Android wraps any exception inside the handler as `result.error("native_error", e.message, null)`.

iOS, macOS, Windows, and Linux success paths always return a map for the five known methods; they do not use the Android `native_error` code.

Need `WidgetsFlutterBinding.ensureInitialized()` before the first invoke so the channel is registered.
