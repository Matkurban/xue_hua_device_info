#ifndef FLUTTER_PLUGIN_XUE_HUA_DEVICE_INFO_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_DEVICE_INFO_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace xue_hua_device_info {

class XueHuaDeviceInfoPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  XueHuaDeviceInfoPlugin();

  virtual ~XueHuaDeviceInfoPlugin();

  // Disallow copy and assign.
  XueHuaDeviceInfoPlugin(const XueHuaDeviceInfoPlugin&) = delete;
  XueHuaDeviceInfoPlugin& operator=(const XueHuaDeviceInfoPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace xue_hua_device_info

#endif  // FLUTTER_PLUGIN_XUE_HUA_DEVICE_INFO_PLUGIN_H_
