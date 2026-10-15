#include <gtest/gtest.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>

#include "device_info_helpers.h"

namespace xue_hua_device_info {
namespace test {

class FakeRootTest : public ::testing::Test {
 protected:
  void SetUp() override {
    char tmpl[] = "/tmp/xhdi_test_XXXXXX";
    ASSERT_NE(mkdtemp(tmpl), nullptr);
    root_ = tmpl;
  }
  void TearDown() override {
    std::string cmd = "rm -rf '" + root_ + "'";
    ASSERT_EQ(system(cmd.c_str()), 0);
  }
  void Mkdir(const std::string& rel) {
    std::string cmd = "mkdir -p '" + root_ + "/" + rel + "'";
    ASSERT_EQ(system(cmd.c_str()), 0);
  }
  void Write(const std::string& rel, const std::string& content) {
    const size_t slash = rel.find_last_of('/');
    if (slash != std::string::npos) Mkdir(rel.substr(0, slash));
    std::ofstream out(root_ + "/" + rel);
    out << content;
  }
  std::string root_;
};

TEST(Helpers, TrimStripsWhitespace) {
  EXPECT_EQ(Trim("  abc \r\n"), "abc");
  EXPECT_EQ(Trim("\n\n"), "");
  EXPECT_EQ(Trim(""), "");
}

TEST_F(FakeRootTest, ReadTrimmedFileHandlesMissingAndPlaceholders) {
  EXPECT_EQ(ReadTrimmedFile(root_ + "/missing"), "");
  Write("a", "hello\n");
  Write("b", "None\n");
  Write("c", "To be filled by O.E.M.\n");
  EXPECT_EQ(ReadTrimmedFile(root_ + "/a"), "hello");
  EXPECT_EQ(ReadTrimmedFile(root_ + "/b"), "");
  EXPECT_EQ(ReadTrimmedFile(root_ + "/c"), "");
}

TEST_F(FakeRootTest, DeviceIdPrefersProductUuid) {
  Write("sys/class/dmi/id/product_uuid", "UUID-1\n");
  Write("etc/machine-id", "machine\n");
  EXPECT_EQ(ResolveDeviceId(root_), "UUID-1");
}

TEST_F(FakeRootTest, DeviceIdFallsBackToMachineId) {
  Write("etc/machine-id", "machine\n");
  Write("var/lib/dbus/machine-id", "dbus\n");
  EXPECT_EQ(ResolveDeviceId(root_), "machine");
}

TEST_F(FakeRootTest, DeviceIdFallsBackToDbusMachineId) {
  Write("etc/machine-id", "\n");
  Write("var/lib/dbus/machine-id", "dbus\n");
  EXPECT_EQ(ResolveDeviceId(root_), "dbus");
}

TEST_F(FakeRootTest, DeviceIdSkipsPlaceholders) {
  Write("sys/class/dmi/id/product_uuid",
        "00000000-0000-0000-0000-000000000000\n");
  Write("etc/machine-id", "uninitialized\n");
  Write("var/lib/dbus/machine-id", "0123456789abcdef0123456789abcdef\n");
  EXPECT_EQ(ResolveDeviceId(root_), "0123456789abcdef0123456789abcdef");
  EXPECT_FALSE(IsUsableId("FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"));
  EXPECT_FALSE(IsUsableId(""));
  EXPECT_TRUE(IsUsableId("4c4c4544-0042-4210-8052-b8c04f4b4d32"));
}

TEST_F(FakeRootTest, DeviceIdEmptyWhenNothingAvailable) {
  EXPECT_EQ(ResolveDeviceId(root_), "");
}

TEST_F(FakeRootTest, BatteryNotFoundWithoutPowerSupply) {
  EXPECT_FALSE(ReadBattery(root_).found);
}

TEST_F(FakeRootTest, BatterySkipsMainsAndDeviceScope) {
  Write("sys/class/power_supply/AC/type", "Mains\n");
  Write("sys/class/power_supply/hidpp_battery_0/type", "Battery\n");
  Write("sys/class/power_supply/hidpp_battery_0/scope", "Device\n");
  Write("sys/class/power_supply/hidpp_battery_0/capacity", "10\n");
  Write("sys/class/power_supply/macsmc-battery/type", "Battery\n");
  Write("sys/class/power_supply/macsmc-battery/scope", "System\n");
  Write("sys/class/power_supply/macsmc-battery/capacity", "87\n");
  Write("sys/class/power_supply/macsmc-battery/status", "Charging\n");
  Write("sys/class/power_supply/macsmc-battery/health", "Good\n");
  const BatteryReading b = ReadBattery(root_);
  ASSERT_TRUE(b.found);
  EXPECT_DOUBLE_EQ(b.level, 87.0);
  EXPECT_TRUE(b.is_charging);
  EXPECT_EQ(b.health, "Good");
}

TEST_F(FakeRootTest, BatterySkipsAbsentAndMapsUnknownHealth) {
  Write("sys/class/power_supply/BAT0/type", "Battery\n");
  Write("sys/class/power_supply/BAT0/present", "0\n");
  Write("sys/class/power_supply/BAT0/capacity", "10\n");
  Write("sys/class/power_supply/BAT1/type", "Battery\n");
  Write("sys/class/power_supply/BAT1/present", "1\n");
  Write("sys/class/power_supply/BAT1/capacity", "60\n");
  Write("sys/class/power_supply/BAT1/health", "Unknown\n");
  Write("sys/class/power_supply/BAT1/status", "Not charging\n");
  const BatteryReading b = ReadBattery(root_);
  ASSERT_TRUE(b.found);
  EXPECT_DOUBLE_EQ(b.level, 60.0);
  EXPECT_FALSE(b.is_charging);
  EXPECT_EQ(b.health, "");
}

TEST_F(FakeRootTest, BatteryDischargingAndMissingHealth) {
  Write("sys/class/power_supply/BAT1/type", "Battery\n");
  Write("sys/class/power_supply/BAT1/capacity", "42\n");
  Write("sys/class/power_supply/BAT1/status", "Discharging\n");
  const BatteryReading b = ReadBattery(root_);
  ASSERT_TRUE(b.found);
  EXPECT_DOUBLE_EQ(b.level, 42.0);
  EXPECT_FALSE(b.is_charging);
  EXPECT_EQ(b.health, "");
}

TEST_F(FakeRootTest, BatteryFullCountsAsCharging) {
  Write("sys/class/power_supply/BAT0/type", "Battery\n");
  Write("sys/class/power_supply/BAT0/capacity", "100\n");
  Write("sys/class/power_supply/BAT0/status", "Full\n");
  EXPECT_TRUE(ReadBattery(root_).is_charging);
}

TEST_F(FakeRootTest, BatteryRejectsInvalidCapacity) {
  Write("sys/class/power_supply/BAT0/type", "Battery\n");
  Write("sys/class/power_supply/BAT0/capacity", "abc\n");
  Write("sys/class/power_supply/BAT1/type", "Battery\n");
  Write("sys/class/power_supply/BAT1/capacity", "250\n");
  EXPECT_FALSE(ReadBattery(root_).found);
}

TEST_F(FakeRootTest, BatteryFallsThroughToNextValidEntry) {
  Write("sys/class/power_supply/BAT0/type", "Battery\n");  // no capacity
  Write("sys/class/power_supply/BAT1/type", "Battery\n");
  Write("sys/class/power_supply/BAT1/capacity", "55\n");
  const BatteryReading b = ReadBattery(root_);
  ASSERT_TRUE(b.found);
  EXPECT_DOUBLE_EQ(b.level, 55.0);
}

TEST_F(FakeRootTest, ClassifyInterface) {
  Mkdir("sys/class/net/wlp2s0/wireless");
  Mkdir("sys/class/net/foo0/wireless");
  Mkdir("sys/class/net/mybr/bridge");
  Write("sys/class/net/mytun/tun_flags", "0x1002\n");
  EXPECT_EQ(ClassifyInterface("wlp2s0", root_), InterfaceKind::kWifi);
  EXPECT_EQ(ClassifyInterface("foo0", root_), InterfaceKind::kWifi);
  EXPECT_EQ(ClassifyInterface("wlan9", root_), InterfaceKind::kWifi);
  EXPECT_EQ(ClassifyInterface("mybr", root_), InterfaceKind::kVirtual);
  EXPECT_EQ(ClassifyInterface("mytun", root_), InterfaceKind::kVirtual);
  EXPECT_EQ(ClassifyInterface("docker0", root_), InterfaceKind::kVirtual);
  EXPECT_EQ(ClassifyInterface("veth1234", root_), InterfaceKind::kVirtual);
  EXPECT_EQ(ClassifyInterface("br-abcd", root_), InterfaceKind::kVirtual);
  EXPECT_EQ(ClassifyInterface("eth0", root_), InterfaceKind::kEthernet);
  EXPECT_EQ(ClassifyInterface("enp3s0", root_), InterfaceKind::kEthernet);
  EXPECT_EQ(ClassifyInterface("usb0", root_), InterfaceKind::kOther);
}

TEST(Helpers, ParseDefaultRouteInterface) {
  const std::string route =
      "Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT\n"
      "eth0\t00000000\t0102A8C0\t0003\t0\t0\t600\t00000000\t0\t0\t0\n"
      "wlan0\t00000000\t0102A8C0\t0003\t0\t0\t100\t00000000\t0\t0\t0\n"
      "eth0\t0002A8C0\t00000000\t0001\t0\t0\t0\t00FFFFFF\t0\t0\t0\n";
  EXPECT_EQ(ParseDefaultRouteInterface(route), "wlan0");
  EXPECT_EQ(ParseDefaultRouteInterface(""), "");
  EXPECT_EQ(ParseDefaultRouteInterface("Iface\tDestination\n"), "");
}

TEST(Helpers, ParseDefaultRouteIgnoresDownRoutes) {
  const std::string route =
      "Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\n"
      "eth0\t00000000\t0102A8C0\t0002\t0\t0\t0\t00000000\n"
      "eth1\t00000000\t0102A8C0\t0003\t0\t0\t0\t00FFFFFF\n";
  EXPECT_EQ(ParseDefaultRouteInterface(route), "");
}

TEST_F(FakeRootTest, SelectNetworkUsesSingleInterfaceForAllFields) {
  Write("sys/class/net/eth0/address", "aa:aa:aa:aa:aa:aa\n");
  Mkdir("sys/class/net/wlan0/wireless");
  Write("sys/class/net/wlan0/address", "bb:bb:bb:bb:bb:bb\n");
  std::vector<NetworkCandidate> c = {
      {"lo", "127.0.0.1", true, true},
      {"eth0", "10.0.0.2", true, false},
      {"wlan0", "192.168.1.5", true, false},
  };
  NetworkSelection s = SelectNetwork(c, "wlan0", root_);
  ASSERT_TRUE(s.found);
  EXPECT_EQ(s.name, "wlan0");
  EXPECT_EQ(s.ipv4, "192.168.1.5");
  EXPECT_EQ(s.mac, "bb:bb:bb:bb:bb:bb");
  EXPECT_EQ(s.type, "wifi");

  s = SelectNetwork(c, "eth0", root_);
  EXPECT_EQ(s.name, "eth0");
  EXPECT_EQ(s.mac, "aa:aa:aa:aa:aa:aa");
  EXPECT_EQ(s.type, "ethernet");
}

TEST_F(FakeRootTest, SelectNetworkDeprioritizesVirtual) {
  Write("sys/class/net/docker0/address", "02:42:00:00:00:01\n");
  Write("sys/class/net/enp1s0/address", "cc:cc:cc:cc:cc:cc\n");
  std::vector<NetworkCandidate> c = {
      {"docker0", "172.17.0.1", true, false},
      {"enp1s0", "10.1.1.9", true, false},
  };
  // Even when a virtual interface holds the default route, physical wins.
  NetworkSelection s = SelectNetwork(c, "docker0", root_);
  EXPECT_EQ(s.name, "enp1s0");
  EXPECT_EQ(s.type, "ethernet");
}

TEST_F(FakeRootTest, SelectNetworkFallsBackToVirtualAsUnknown) {
  Write("sys/class/net/docker0/address", "02:42:00:00:00:01\n");
  std::vector<NetworkCandidate> c = {{"docker0", "172.17.0.1", true, false}};
  NetworkSelection s = SelectNetwork(c, "", root_);
  ASSERT_TRUE(s.found);
  EXPECT_EQ(s.type, "unknown");
  EXPECT_EQ(s.mac, "02:42:00:00:00:01");
}

TEST_F(FakeRootTest, SelectNetworkSkipsDownLoopbackAndNoIp) {
  std::vector<NetworkCandidate> c = {
      {"lo", "127.0.0.1", true, true},
      {"eth0", "10.0.0.2", false, false},
      {"eth1", "", true, false},
  };
  EXPECT_FALSE(SelectNetwork(c, "", root_).found);
  EXPECT_FALSE(SelectNetwork({}, "", root_).found);
}

TEST_F(FakeRootTest, SelectNetworkDoesNotSkipNamesStartingWithLo) {
  Write("sys/class/net/looper0/address", "dd:dd:dd:dd:dd:dd\n");
  std::vector<NetworkCandidate> c = {
      {"lo", "127.0.0.1", true, true},
      {"looper0", "10.9.9.9", true, false},
  };
  NetworkSelection s = SelectNetwork(c, "", root_);
  ASSERT_TRUE(s.found);
  EXPECT_EQ(s.name, "looper0");
  EXPECT_EQ(s.type, "unknown");
}

TEST_F(FakeRootTest, SelectNetworkIgnoresZeroMac) {
  Write("sys/class/net/eth0/address", "00:00:00:00:00:00\n");
  std::vector<NetworkCandidate> c = {{"eth0", "10.0.0.2", true, false}};
  NetworkSelection s = SelectNetwork(c, "", root_);
  ASSERT_TRUE(s.found);
  EXPECT_EQ(s.mac, "");
}

}  // namespace test
}  // namespace xue_hua_device_info
