package com.flutter_rust_bridge.xue_hua_device_info

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class XueHuaDeviceInfoPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var deviceInfo: AndroidDeviceInfo? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        deviceInfo = AndroidDeviceInfo(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, "xue_hua_device_info")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        deviceInfo = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val info = deviceInfo
        if (info == null) {
            result.error("NOT_READY", "Plugin not attached", null)
            return
        }

        try {
            when (call.method) {
                "getDeviceInfo" -> result.success(info.getDeviceInfo())
                "getBatteryInfo" -> result.success(info.getBatteryInfo())
                "getNetworkInfo" -> result.success(info.getNetworkInfo())
                "getStorageInfo" -> result.success(info.getStorageInfo())
                "getDisplayInfo" -> result.success(info.getDisplayInfo())
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(call.method, e.message, null)
        }
    }
}
