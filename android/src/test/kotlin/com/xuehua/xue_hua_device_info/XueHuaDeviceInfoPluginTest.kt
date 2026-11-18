package com.xuehua.xue_hua_device_info

import java.net.InetAddress
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class XueHuaDeviceInfoPluginTest {
    @Test
    fun sanitizeBatteryLevel_validRange() {
        assertEquals(0.0, DeviceInfoHelpers.sanitizeBatteryLevel(0))
        assertEquals(85.0, DeviceInfoHelpers.sanitizeBatteryLevel(85))
        assertEquals(100.0, DeviceInfoHelpers.sanitizeBatteryLevel(100))
    }

    @Test
    fun sanitizeBatteryLevel_intMinAndOutOfRange_areNull() {
        assertNull(DeviceInfoHelpers.sanitizeBatteryLevel(Int.MIN_VALUE))
        assertNull(DeviceInfoHelpers.sanitizeBatteryLevel(-1))
        assertNull(DeviceInfoHelpers.sanitizeBatteryLevel(101))
    }

    @Test
    fun mapBatteryHealth_knownCodes() {
        assertEquals("good", DeviceInfoHelpers.mapBatteryHealth(2))
        assertEquals("overheat", DeviceInfoHelpers.mapBatteryHealth(3))
        assertEquals("dead", DeviceInfoHelpers.mapBatteryHealth(4))
        assertEquals("over_voltage", DeviceInfoHelpers.mapBatteryHealth(5))
        assertEquals("unspecified_failure", DeviceInfoHelpers.mapBatteryHealth(6))
        assertEquals("cold", DeviceInfoHelpers.mapBatteryHealth(7))
        assertEquals("unknown", DeviceInfoHelpers.mapBatteryHealth(1))
        assertEquals("unknown", DeviceInfoHelpers.mapBatteryHealth(-1))
        assertEquals("unknown", DeviceInfoHelpers.mapBatteryHealth(99))
    }

    @Test
    fun mapBatteryHealthStatus_and_mapChargingState() {
        assertEquals(WireBatteryHealthStatus.GOOD, DeviceInfoHelpers.mapBatteryHealthStatus(2))
        assertEquals(WireBatteryHealthStatus.OVERHEAT, DeviceInfoHelpers.mapBatteryHealthStatus(3))
        assertEquals(WireBatteryHealthStatus.UNKNOWN, DeviceInfoHelpers.mapBatteryHealthStatus(-1))

        assertEquals(WireBatteryChargingState.CHARGING, DeviceInfoHelpers.mapChargingState(2))
        assertEquals(WireBatteryChargingState.DISCHARGING, DeviceInfoHelpers.mapChargingState(3))
        assertEquals(WireBatteryChargingState.NOT_CHARGING, DeviceInfoHelpers.mapChargingState(4))
        assertEquals(WireBatteryChargingState.FULL, DeviceInfoHelpers.mapChargingState(5))
        assertEquals(WireBatteryChargingState.UNKNOWN, DeviceInfoHelpers.mapChargingState(-1))
    }

    @Test
    fun mapNetworkType_mapsAllConnectionTypesIncludingVpn() {
        assertEquals("wifi", DeviceInfoHelpers.mapNetworkType(WireNetworkConnectionType.WIFI))
        assertEquals("ethernet", DeviceInfoHelpers.mapNetworkType(WireNetworkConnectionType.ETHERNET))
        assertEquals("cellular", DeviceInfoHelpers.mapNetworkType(WireNetworkConnectionType.CELLULAR))
        assertEquals("vpn", DeviceInfoHelpers.mapNetworkType(WireNetworkConnectionType.VPN))
        assertEquals("loopback", DeviceInfoHelpers.mapNetworkType(WireNetworkConnectionType.LOOPBACK))
        assertEquals("none", DeviceInfoHelpers.mapNetworkType(WireNetworkConnectionType.NONE))
        assertEquals("unknown", DeviceInfoHelpers.mapNetworkType(WireNetworkConnectionType.UNKNOWN))
    }

    @Test
    fun isUsableIpv4_filtersLoopbackLinkLocalAndFakeIp() {
        assertFalse(DeviceInfoHelpers.isUsableIpv4(InetAddress.getByName("127.0.0.1")))
        assertFalse(DeviceInfoHelpers.isUsableIpv4(InetAddress.getByName("169.254.1.2")))
        assertFalse(DeviceInfoHelpers.isUsableIpv4(InetAddress.getByName("198.18.0.1")))
        assertFalse(DeviceInfoHelpers.isUsableIpv4(InetAddress.getByName("198.19.255.1")))
        assertTrue(DeviceInfoHelpers.isUsableIpv4(InetAddress.getByName("192.168.1.10")))
        assertTrue(DeviceInfoHelpers.isUsableIpv4(InetAddress.getByName("10.0.0.5")))
        assertTrue(DeviceInfoHelpers.isUsableIpv4(InetAddress.getByName("8.8.8.8")))
    }

    @Test
    fun pickPreferredIpv4_prefersSiteLocal() {
        val picked =
            DeviceInfoHelpers.pickPreferredIpv4(
                listOf(
                    InetAddress.getByName("8.8.8.8"),
                    InetAddress.getByName("192.168.0.20"),
                    InetAddress.getByName("169.254.1.1"),
                ),
            )
        assertEquals("192.168.0.20", picked)
    }

    @Test
    fun pickPreferredIpv4_skipsAllUnusable() {
        assertNull(
            DeviceInfoHelpers.pickPreferredIpv4(
                listOf(
                    InetAddress.getByName("127.0.0.1"),
                    InetAddress.getByName("169.254.1.1"),
                    InetAddress.getByName("198.18.0.1"),
                ),
            ),
        )
    }

    @Test
    fun pigeonDataClasses_roundTripToList() {
        val device =
            WireDeviceInfo(
                deviceId = "id-1",
                manufacturer = "Google",
                model = "Pixel",
                serial = null,
                name = "Pixel 9",
                operatingSystem = "android",
                osVersion = "16",
                architecture = "arm64-v8a",
            )
        assertEquals(device, WireDeviceInfo.fromList(device.toList()))
    }
}
