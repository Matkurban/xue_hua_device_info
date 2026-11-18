#ifndef FLUTTER_PLUGIN_XUE_HUA_DEVICE_INFO_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_DEVICE_INFO_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "messages.g.h"

namespace xue_hua_device_info {

class XueHuaDeviceInfoPlugin : public flutter::Plugin,
                               public XueHuaDeviceInfoHostApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  XueHuaDeviceInfoPlugin();

  ~XueHuaDeviceInfoPlugin() override;

  // Disallow copy and assign.
  XueHuaDeviceInfoPlugin(const XueHuaDeviceInfoPlugin&) = delete;
  XueHuaDeviceInfoPlugin& operator=(const XueHuaDeviceInfoPlugin&) = delete;

  // XueHuaDeviceInfoHostApi implementation.
  ErrorOr<WireDeviceInfo> GetDeviceInfo() override;
  ErrorOr<WireBatteryInfo> GetBatteryInfo() override;
  ErrorOr<WireNetworkInfo> GetNetworkInfo() override;
  ErrorOr<WireStorageInfo> GetStorageInfo() override;
  ErrorOr<WireDisplayInfo> GetDisplayInfo() override;
};

}  // namespace xue_hua_device_info

#endif  // FLUTTER_PLUGIN_XUE_HUA_DEVICE_INFO_PLUGIN_H_
