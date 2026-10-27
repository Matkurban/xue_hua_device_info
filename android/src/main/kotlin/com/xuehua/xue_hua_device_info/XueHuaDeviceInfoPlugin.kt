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
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.Inet4Address
import java.net.InetAddress
import java.net.NetworkInterface

/** XueHuaDeviceInfoPlugin */
class XueHuaDeviceInfoPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "xue_hua_device_info")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        try {
            when (call.method) {
                "getDeviceInfo" -> result.success(getDeviceInfo())
                "getBatteryInfo" -> result.success(getBatteryInfo())
                "getNetworkInfo" -> result.success(getNetworkInfo())
                "getStorageInfo" -> result.success(getStorageInfo())
                "getDisplayInfo" -> result.success(getDisplayInfo())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("native_error", e.message, null)
        }
    }

    @SuppressLint("HardwareIds")
    private fun getDeviceInfo(): Map<String, Any?> {
        val androidId =
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        val deviceName =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
                    ?: Build.MODEL
            } else {
                Build.MODEL
            }
        return mapOf(
            "deviceId" to androidId,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "serial" to null,
            "name" to deviceName,
        )
    }

    private fun getBatteryInfo(): Map<String, Any?> {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val rawLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val level = DeviceInfoHelpers.sanitizeBatteryLevel(rawLevel)
        val intent =
            context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging =
            status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL
        val healthCode = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1
        return mapOf(
            "level" to level,
            "isCharging" to isCharging,
            "health" to DeviceInfoHelpers.mapBatteryHealth(healthCode),
        )
    }

    private fun getNetworkInfo(): Map<String, Any?> {
        val connectivity =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivity.activeNetwork
        val caps = network?.let { connectivity.getNetworkCapabilities(it) }
        val networkType =
            when {
                caps == null -> "none"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                else -> "unknown"
            }
        val link = network?.let { connectivity.getLinkProperties(it) }
        val ip = ipv4FromLinkProperties(link) ?: ipv4FromNetworkInterfaces()
        return mapOf(
            "ipAddress" to ip,
            "networkType" to networkType,
            "macAddress" to null,
        )
    }

    /**
     * Preferred path (Android docs): IPv4 from [LinkProperties] of the active
     * default network via [ConnectivityManager.getLinkProperties].
     */
    private fun ipv4FromLinkProperties(link: LinkProperties?): String? {
        if (link == null) return null
        val addresses = link.linkAddresses.map { it.address }
        return DeviceInfoHelpers.pickPreferredIpv4(addresses)
    }

    /** Fallback when LinkProperties has no usable IPv4. */
    private fun ipv4FromNetworkInterfaces(): String? {
        val interfaces =
            try {
                NetworkInterface.getNetworkInterfaces()
            } catch (_: Exception) {
                null
            } ?: return null
        val candidates = mutableListOf<InetAddress>()
        for (intf in interfaces) {
            if (!intf.isUp || intf.isLoopback) continue
            for (addr in intf.inetAddresses) {
                if (addr is Inet4Address) candidates.add(addr)
            }
        }
        return DeviceInfoHelpers.pickPreferredIpv4(candidates)
    }

    private fun getStorageInfo(): Map<String, Any?> {
        val path = Environment.getDataDirectory()
        val stat = StatFs(path.path)
        val total = stat.blockCountLong * stat.blockSizeLong
        val free = stat.availableBlocksLong * stat.blockSizeLong
        return mapOf(
            "totalBytes" to total,
            "freeBytes" to free,
            // Mobile flash (eMMC/UFS); no public rotational API - keep "internal".
            "storageType" to "internal",
        )
    }

    private fun getDisplayInfo(): Map<String, Any?> {
        val display = resolveDefaultDisplay()
        val metrics = context.resources.displayMetrics
        // Display.Mode physical size (API 23+; minSdk 24). Avoids deprecated
        // Display.getRealMetrics and reports the active mode's native pixels.
        val mode = display?.mode
        val width = mode?.physicalWidth ?: metrics.widthPixels
        val height = mode?.physicalHeight ?: metrics.heightPixels
        val refreshRate =
            when {
                mode != null && mode.refreshRate > 0f -> mode.refreshRate.toDouble()
                display != null && display.refreshRate > 0f -> display.refreshRate.toDouble()
                else -> null
            }
        return mapOf(
            "width" to width,
            "height" to height,
            "scaleFactor" to metrics.density.toDouble(),
            "refreshRate" to refreshRate,
        )
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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
