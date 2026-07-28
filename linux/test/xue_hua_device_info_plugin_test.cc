#include <gtest/gtest.h>

#include "include/xue_hua_device_info/xue_hua_device_info_plugin.h"

namespace xue_hua_device_info {
namespace test {

// Native Linux collection is exercised via the example app / integration tests.
// Keep a compile smoke test so the plugin sources remain linked in the test target.
TEST(XueHuaDeviceInfoPlugin, PluginTypeIsRegistered) {
  EXPECT_NE(xue_hua_device_info_plugin_get_type(), static_cast<GType>(0));
}

}  // namespace test
}  // namespace xue_hua_device_info
