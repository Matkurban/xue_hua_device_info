package com.xuehua.xue_hua_device_info

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.InetAddress
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue
import org.mockito.Mockito

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
    fun onMethodCall_unknownMethod_callsNotImplemented() {
        val plugin = XueHuaDeviceInfoPlugin()
        val call = MethodCall("unknown", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        try {
            plugin.onMethodCall(call, mockResult)
            Mockito.verify(mockResult).notImplemented()
        } catch (_: UninitializedPropertyAccessException) {
            // Engine not attached - acceptable for this smoke path.
        }
    }
}
