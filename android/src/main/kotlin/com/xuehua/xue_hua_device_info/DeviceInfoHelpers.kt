package com.xuehua.xue_hua_device_info

import java.net.Inet4Address
import java.net.InetAddress

/** Pure helpers for unit testing without an Android Context. */
internal object DeviceInfoHelpers {
    /** Maps BatteryManager capacity to 0-100, or null when unavailable. */
    fun sanitizeBatteryLevel(raw: Int): Double? = if (raw in 0..100) raw.toDouble() else null

    /**
     * Maps [android.os.BatteryManager] EXTRA_HEALTH codes to Dart strings.
     * Unknown / unrecognized codes become `"unknown"`.
     */
    fun mapBatteryHealth(healthCode: Int): String =
        when (healthCode) {
            // BatteryManager.BATTERY_HEALTH_* constants (keep numeric to stay Context-free).
            2 -> "good" // BATTERY_HEALTH_GOOD
            3 -> "overheat" // BATTERY_HEALTH_OVERHEAT
            4 -> "dead" // BATTERY_HEALTH_DEAD
            5 -> "over_voltage" // BATTERY_HEALTH_OVER_VOLTAGE
            6 -> "unspecified_failure" // BATTERY_HEALTH_UNSPECIFIED_FAILURE
            7 -> "cold" // BATTERY_HEALTH_COLD
            else -> "unknown" // includes BATTERY_HEALTH_UNKNOWN (1) and missing (-1)
        }

    /** Maps [android.os.BatteryManager] EXTRA_HEALTH codes to [WireBatteryHealthStatus]. */
    fun mapBatteryHealthStatus(healthCode: Int): WireBatteryHealthStatus =
        when (healthCode) {
            2 -> WireBatteryHealthStatus.GOOD
            3 -> WireBatteryHealthStatus.OVERHEAT
            4 -> WireBatteryHealthStatus.DEAD
            5 -> WireBatteryHealthStatus.OVER_VOLTAGE
            6 -> WireBatteryHealthStatus.UNSPECIFIED_FAILURE
            7 -> WireBatteryHealthStatus.COLD
            else -> WireBatteryHealthStatus.UNKNOWN
        }

    /** Maps [android.os.BatteryManager] EXTRA_STATUS codes to [WireBatteryChargingState]. */
    fun mapChargingState(statusCode: Int): WireBatteryChargingState =
        when (statusCode) {
            2 -> WireBatteryChargingState.CHARGING // BATTERY_STATUS_CHARGING
            3 -> WireBatteryChargingState.DISCHARGING // BATTERY_STATUS_DISCHARGING
            4 -> WireBatteryChargingState.NOT_CHARGING // BATTERY_STATUS_NOT_CHARGING
            5 -> WireBatteryChargingState.FULL // BATTERY_STATUS_FULL
            else -> WireBatteryChargingState.UNKNOWN
        }

    /** Maps [WireNetworkConnectionType] to its canonical wire string code. */
    fun mapNetworkType(connectionType: WireNetworkConnectionType): String =
        when (connectionType) {
            WireNetworkConnectionType.WIFI -> "wifi"
            WireNetworkConnectionType.ETHERNET -> "ethernet"
            WireNetworkConnectionType.CELLULAR -> "cellular"
            WireNetworkConnectionType.VPN -> "vpn"
            WireNetworkConnectionType.LOOPBACK -> "loopback"
            WireNetworkConnectionType.NONE -> "none"
            WireNetworkConnectionType.UNKNOWN -> "unknown"
        }

    /**
     * True for a unicast IPv4 that is usable as a local interface address:
     * not loopback, not link-local (`169.254/16`), not Clash-style fake-IP
     * (`198.18.0.0/15`).
     */
    fun isUsableIpv4(address: InetAddress?): Boolean {
        if (address == null || address !is Inet4Address) return false
        if (address.isLoopbackAddress || address.isAnyLocalAddress) return false
        if (address.isLinkLocalAddress) return false
        val bytes = address.address ?: return false
        if (bytes.size != 4) return false
        // RFC 2544 benchmarking range used by Clash Meta / similar local proxies.
        val b0 = bytes[0].toInt() and 0xff
        val b1 = bytes[1].toInt() and 0xff
        if (b0 == 198 && (b1 and 0xfe) == 18) return false // 198.18.0.0/15
        return true
    }

    /** Prefer site-local (RFC 1918) among usable candidates; keep first otherwise. */
    fun pickPreferredIpv4(candidates: List<InetAddress>): String? {
        val usable = candidates.filter { isUsableIpv4(it) }
        if (usable.isEmpty()) return null
        val siteLocal = usable.firstOrNull { it.isSiteLocalAddress }
        return (siteLocal ?: usable.first()).hostAddress
    }
}
