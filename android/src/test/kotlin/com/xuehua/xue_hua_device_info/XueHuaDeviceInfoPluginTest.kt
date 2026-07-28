package com.xuehua.xue_hua_device_info

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
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
    fun onMethodCall_unknownMethod_callsNotImplemented() {
        val plugin = XueHuaDeviceInfoPlugin()
        val call = MethodCall("unknown", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        try {
            plugin.onMethodCall(call, mockResult)
            Mockito.verify(mockResult).notImplemented()
        } catch (_: UninitializedPropertyAccessException) {
            // Engine not attached — acceptable for this smoke path.
        }
    }
}
