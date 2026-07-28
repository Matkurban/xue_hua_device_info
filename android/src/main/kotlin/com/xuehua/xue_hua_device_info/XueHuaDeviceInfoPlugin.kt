package com.xuehua.xue_hua_device_info

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.Inet4Address
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
        val health =
            when (healthCode) {
                BatteryManager.BATTERY_HEALTH_GOOD -> "good"
                BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
                BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
                BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over_voltage"
                BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "unspecified_failure"
                BatteryManager.BATTERY_HEALTH_COLD -> "cold"
                else -> "unknown"
            }
        return mapOf(
            "level" to level,
            "isCharging" to isCharging,
            "health" to health,
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
        return mapOf(
            "ipAddress" to localIpv4(),
            "networkType" to networkType,
            "macAddress" to null,
        )
    }

    private fun localIpv4(): String? {
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return null
        for (intf in interfaces) {
            if (!intf.isUp || intf.isLoopback) continue
            for (addr in intf.inetAddresses) {
                if (!addr.isLoopbackAddress && addr is Inet4Address) {
                    return addr.hostAddress
                }
            }
        }
        return null
    }

    private fun getStorageInfo(): Map<String, Any?> {
        val path = Environment.getDataDirectory()
        val stat = StatFs(path.path)
        val total = stat.blockCountLong * stat.blockSizeLong
        val free = stat.availableBlocksLong * stat.blockSizeLong
        return mapOf(
            "totalBytes" to total,
            "freeBytes" to free,
            "storageType" to "internal",
        )
    }

    private fun getDisplayInfo(): Map<String, Any?> {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        val refreshRate =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.display?.refreshRate?.toDouble()
            } else {
                @Suppress("DEPRECATION")
                wm.defaultDisplay.refreshRate.toDouble()
            }
        return mapOf(
            "width" to metrics.widthPixels,
            "height" to metrics.heightPixels,
            "scaleFactor" to metrics.density.toDouble(),
            "refreshRate" to refreshRate,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
