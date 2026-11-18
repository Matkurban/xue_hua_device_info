#include <gtest/gtest.h>

#include "xue_hua_device_info_plugin.h"

namespace xue_hua_device_info {
namespace test {

TEST(XueHuaDeviceInfoPlugin, GetDeviceInfoSucceeds) {
  XueHuaDeviceInfoPlugin plugin;
  ErrorOr<PigeonDeviceInfo> result = plugin.GetDeviceInfo();
  EXPECT_FALSE(result.has_error());
  ASSERT_NE(result.value().operating_system(), nullptr);
  EXPECT_EQ(*result.value().operating_system(), "windows");
}

}  // namespace test
}  // namespace xue_hua_device_info
