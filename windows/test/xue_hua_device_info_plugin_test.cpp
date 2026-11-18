#include <gtest/gtest.h>

#include "xue_hua_device_info_plugin.h"

namespace xue_hua_device_info {
namespace test {

TEST(XueHuaDeviceInfoPlugin, GetDeviceInfoSucceeds) {
  XueHuaDeviceInfoPlugin plugin;
  ErrorOr<WireDeviceInfo> result = plugin.GetDeviceInfo();
  EXPECT_FALSE(result.has_error());
  ASSERT_NE(result.value().operating_system(), nullptr);
  EXPECT_EQ(*result.value().operating_system(), "windows");
}

TEST(XueHuaDeviceInfoPlugin, SubsystemQueriesSucceed) {
  XueHuaDeviceInfoPlugin plugin;
  EXPECT_FALSE(plugin.GetBatteryInfo().has_error());
  EXPECT_FALSE(plugin.GetNetworkInfo().has_error());
  EXPECT_FALSE(plugin.GetStorageInfo().has_error());
  EXPECT_FALSE(plugin.GetDisplayInfo().has_error());
}

}  // namespace test
}  // namespace xue_hua_device_info
