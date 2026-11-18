package com.xuehua.xue_hua_device_info

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface

/** XueHuaDeviceInfoPlugin implemented with Pigeon HostApi. */
class XueHuaDeviceInfoPlugin :
    FlutterPlugin,
    XueHuaDeviceInfoHostApi {
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        XueHuaDeviceInfoHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        XueHuaDeviceInfoHostApi.setUp(binding.binaryMessenger, null)
    }

    @SuppressLint("HardwareIds")
    override fun getDeviceInfo(): PigeonDeviceInfo {
        try {
            val androidId =
                Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
            val deviceName =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                    Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
                        ?: Build.MODEL
                } else {
                    Build.MODEL
                }
            val abi = Build.SUPPORTED_ABIS.firstOrNull()
            return PigeonDeviceInfo(
                deviceId = androidId,
                manufacturer = Build.MANUFACTURER,
                model = Build.MODEL,
                serial = null,
                name = deviceName,
                operatingSystem = "android",
                osVersion = Build.VERSION.RELEASE,
                architecture = abi,
            )
        } catch (e: Exception) {
            throw FlutterError("native_error", e.message, null)
        }
    }

    override fun getBatteryInfo(): PigeonBatteryInfo {
        try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val rawLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val level = DeviceInfoHelpers.sanitizeBatteryLevel(rawLevel)
            val intent =
                context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val present = intent?.getBooleanExtra(BatteryManager.EXTRA_PRESENT, true) ?: true
            val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging =
                status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
            val healthCode = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1
            return PigeonBatteryInfo(
                level = level,
                isCharging = if (present) isCharging else null,
                chargingState =
                    if (present) {
                        DeviceInfoHelpers.mapChargingState(status)
                    } else {
                        PigeonBatteryChargingState.UNKNOWN
                    },
                healthStatus = DeviceInfoHelpers.mapBatteryHealthStatus(healthCode),
                health = DeviceInfoHelpers.mapBatteryHealth(healthCode),
                hasBattery = present,
            )
        } catch (e: Exception) {
            throw FlutterError("native_error", e.message, null)
        }
    }

    override fun getNetworkInfo(): PigeonNetworkInfo {
        try {
            val connectivity =
                context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivity.activeNetwork
            val caps = network?.let { connectivity.getNetworkCapabilities(it) }
            val connectionType =
                when {
                    caps == null -> PigeonNetworkConnectionType.NONE
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ->
                        PigeonNetworkConnectionType.WIFI
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
                        PigeonNetworkConnectionType.ETHERNET
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
                        PigeonNetworkConnectionType.CELLULAR
                    caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ->
                        PigeonNetworkConnectionType.VPN
                    else -> PigeonNetworkConnectionType.UNKNOWN
                }
            val networkType =
                when (connectionType) {
                    PigeonNetworkConnectionType.NONE -> "none"
                    PigeonNetworkConnectionType.WIFI -> "wifi"
                    PigeonNetworkConnectionType.ETHERNET -> "ethernet"
                    PigeonNetworkConnectionType.CELLULAR -> "cellular"
                    else -> "unknown"
                }
            val link = network?.let { connectivity.getLinkProperties(it) }
            val fallbackPair = ipv4FromNetworkInterfaces()
            val ip = ipv4FromLinkProperties(link) ?: fallbackPair?.first
            val ifaceName = link?.interfaceName ?: fallbackPair?.second
            return PigeonNetworkInfo(
                ipAddress = ip,
                connectionType = connectionType,
                networkType = networkType,
                macAddress = null,
                interfaceName = ifaceName,
            )
        } catch (e: Exception) {
            throw FlutterError("native_error", e.message, null)
        }
    }

    private fun ipv4FromLinkProperties(link: LinkProperties?): String? {
        if (link == null) return null
        val addresses = link.linkAddresses.map { it.address }
        return DeviceInfoHelpers.pickPreferredIpv4(addresses)
    }

    private fun ipv4FromNetworkInterfaces(): Pair<String, String>? {
        val interfaces =
            try {
                NetworkInterface.getNetworkInterfaces()
            } catch (_: Exception) {
                null
            } ?: return null
        val candidates = mutableListOf<Pair<InetAddress, String>>()
        for (intf in interfaces) {
            if (!intf.isUp || intf.isLoopback) continue
            for (addr in intf.inetAddresses) {
                if (addr is Inet4Address && DeviceInfoHelpers.isUsableIpv4(addr)) {
                    candidates.add(addr to intf.name)
                }
            }
        }
        if (candidates.isEmpty()) return null
        val preferred = candidates.firstOrNull { it.first.isSiteLocalAddress } ?: candidates.first()
        val host = preferred.first.hostAddress ?: return null
        return host to preferred.second
    }

    override fun getStorageInfo(): PigeonStorageInfo {
        try {
            val path = Environment.getDataDirectory()
            val stat = StatFs(path.path)
            val total = stat.blockCountLong * stat.blockSizeLong
            val free = stat.availableBlocksLong * stat.blockSizeLong
            return PigeonStorageInfo(
                totalBytes = total,
                freeBytes = free,
                mediumType = PigeonStorageMediumType.INTERNAL_STORAGE,
                storageType = "internal",
            )
        } catch (e: Exception) {
            throw FlutterError("native_error", e.message, null)
        }
    }

    override fun getDisplayInfo(): PigeonDisplayInfo {
        try {
            val display = resolveDefaultDisplay()
            val metrics = context.resources.displayMetrics
            val mode = display?.mode
            val width = (mode?.physicalWidth ?: metrics.widthPixels).toLong()
            val height = (mode?.physicalHeight ?: metrics.heightPixels).toLong()
            val refreshRate =
                when {
                    mode != null && mode.refreshRate > 0f -> mode.refreshRate.toDouble()
                    display != null && display.refreshRate > 0f -> display.refreshRate.toDouble()
                    else -> null
                }
            return PigeonDisplayInfo(
                width = width,
                height = height,
                scaleFactor = metrics.density.toDouble(),
                refreshRate = refreshRate,
            )
        } catch (e: Exception) {
            throw FlutterError("native_error", e.message, null)
        }
    }

    private fun resolveDefaultDisplay(): Display? {
        val dm = context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
        val fromManager = dm?.getDisplay(Display.DEFAULT_DISPLAY)
        if (fromManager != null) return fromManager
        @Suppress("DEPRECATION")
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        return wm.defaultDisplay
    }
}
