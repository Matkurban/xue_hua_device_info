#include "include/xue_hua_device_info/xue_hua_device_info_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xue_hua_device_info_plugin.h"

void XueHuaDeviceInfoPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_device_info::XueHuaDeviceInfoPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
