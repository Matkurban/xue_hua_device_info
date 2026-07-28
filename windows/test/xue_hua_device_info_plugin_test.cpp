#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>

#include <memory>
#include <string>

#include "xue_hua_device_info_plugin.h"

namespace xue_hua_device_info {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(XueHuaDeviceInfoPlugin, GetDeviceInfoReturnsMap) {
  XueHuaDeviceInfoPlugin plugin;
  bool success = false;
  plugin.HandleMethodCall(
      MethodCall("getDeviceInfo", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&success](const EncodableValue* result) {
            success = std::holds_alternative<EncodableMap>(*result);
          },
          nullptr, nullptr));
  EXPECT_TRUE(success);
}

}  // namespace test
}  // namespace xue_hua_device_info
