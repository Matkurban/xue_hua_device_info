package com.flutter_rust_bridge.xue_hua_device_info

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.view.Display
import java.net.Inet4Address

/**
 * Android device info APIs ported from
 * [tauri-plugin-device-info](https://github.com/edisdev/tauri-plugin-device-info).
 */
class AndroidDeviceInfo(private val context: Context) {
    fun getDeviceInfo(): Map<String, Any?> {
        val androidId =
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        val deviceName =
            Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
                ?: Settings.Secure.getString(context.contentResolver, "bluetooth_name")

        return mapOf(
            "uuid" to androidId,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "serial" to androidId,
            "android_id" to androidId,
            "device_name" to deviceName,
        )
    }

    fun getBatteryInfo(): Map<String, Any?> {
        val batteryManager =
            context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level =
            batteryManager
                .getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                .toDouble()

        val ifilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus = context.registerReceiver(null, ifilter)

        val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging =
            status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL

        val healthInt =
            batteryStatus?.getIntExtra(
                BatteryManager.EXTRA_HEALTH,
                BatteryManager.BATTERY_HEALTH_UNKNOWN,
            ) ?: BatteryManager.BATTERY_HEALTH_UNKNOWN

        val health =
            when (healthInt) {
                BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
                BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
                BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
                BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over Voltage"
                BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Unspecified Failure"
                BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
                else -> "Unknown"
            }

        return mapOf(
            "level" to level,
            "isCharging" to isCharging,
            "health" to health,
        )
    }

    fun getNetworkInfo(): Map<String, Any?> {
        val connectivityManager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)

        val networkType =
            when {
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "wifi"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true ->
                    "cellular"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true ->
                    "ethernet"
                else -> "unknown"
            }

        val linkProperties = connectivityManager.getLinkProperties(activeNetwork)
        val ipAddress =
            linkProperties
                ?.linkAddresses
                ?.firstOrNull { it.address is Inet4Address }
                ?.address
                ?.hostAddress ?: "0.0.0.0"

        return mapOf(
            "networkType" to networkType,
            "ipAddress" to ipAddress,
            "macAddress" to "restricted",
        )
    }

    fun getStorageInfo(): Map<String, Any?> {
        val stat = StatFs(Environment.getDataDirectory().path)
        return mapOf(
            "totalSpace" to stat.totalBytes,
            "freeSpace" to stat.availableBytes,
            "storageType" to "internal",
        )
    }

    fun getDisplayInfo(): Map<String, Any?> {
        val metrics = context.resources.displayMetrics
        val displayManager =
            context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
        val refreshRate = display?.refreshRate?.toDouble() ?: 60.0

        return mapOf(
            "width" to metrics.widthPixels,
            "height" to metrics.heightPixels,
            "scaleFactor" to metrics.density.toDouble(),
            "refreshRate" to refreshRate,
        )
    }
}
