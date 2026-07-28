package com.xuehua.xue_hua_device_info

/** Pure helpers for unit testing without an Android Context. */
internal object DeviceInfoHelpers {
    /** Maps BatteryManager capacity to 0–100, or null when unavailable. */
    fun sanitizeBatteryLevel(raw: Int): Double? = if (raw in 0..100) raw.toDouble() else null
}
