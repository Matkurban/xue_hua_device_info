package com.flutter_rust_bridge.xue_hua_device_info

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin

class XueHuaDeviceInfoPlugin : FlutterPlugin {
    companion object {
        init {
            System.loadLibrary("xue_hua_device_info")
        }

        @JvmStatic
        external fun initAndroid(context: Context)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        initAndroid(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
