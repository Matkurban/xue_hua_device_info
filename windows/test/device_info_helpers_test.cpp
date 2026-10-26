#include <gtest/gtest.h>

#include "device_info_helpers.h"

namespace xue_hua_device_info {
namespace test {

TEST(Helpers, TrimAndSanitize) {
  EXPECT_EQ(Trim("  abc\r\n"), "abc");
  EXPECT_EQ(SanitizeHardwareString("  To Be Filled By O.E.M.  "), "");
  EXPECT_EQ(SanitizeHardwareString("System Serial Number"), "");
  EXPECT_EQ(SanitizeHardwareString("Dell Inc."), "Dell Inc.");
  EXPECT_EQ(SanitizeHardwareString("System Manufacturer"), "");
}

TEST(Helpers, Ipv4Classification) {
  EXPECT_TRUE(IsLinkLocalIpv4("169.254.1.2"));
  EXPECT_FALSE(IsLinkLocalIpv4("192.168.1.1"));
  EXPECT_TRUE(IsLoopbackIpv4("127.0.0.1"));
  EXPECT_FALSE(IsUsableIpv4("169.254.10.1"));
  EXPECT_FALSE(IsUsableIpv4("127.0.0.1"));
  EXPECT_FALSE(IsUsableIpv4("198.18.0.1"));
  EXPECT_FALSE(IsUsableIpv4("198.19.1.2"));
  EXPECT_TRUE(IsUsableIpv4("10.0.0.5"));
}

TEST(Helpers, FormatMac) {
  unsigned char ok[6] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55};
  EXPECT_EQ(FormatMac(ok, 6), "00:11:22:33:44:55");
  unsigned char zero[6] = {};
  EXPECT_EQ(FormatMac(zero, 6), "");
  EXPECT_EQ(FormatMac(ok, 5), "");
}

TEST(Helpers, ClassifyAdapter) {
  EXPECT_EQ(ClassifyAdapter(71).type_string, "wifi");
  EXPECT_EQ(ClassifyAdapter(71).kind, AdapterKind::kWifi);
  EXPECT_EQ(ClassifyAdapter(6).type_string, "ethernet");
  EXPECT_EQ(ClassifyAdapter(131).kind, AdapterKind::kVirtual);
  EXPECT_EQ(ClassifyAdapter(6, "Hyper-V Virtual Ethernet Adapter").kind,
            AdapterKind::kVirtual);
  EXPECT_EQ(ClassifyAdapter(23).kind, AdapterKind::kVirtual);
}

TEST(Helpers, StorageTypeFromSeekPenalty) {
  EXPECT_EQ(StorageTypeFromSeekPenalty(true, false), "ssd");
  EXPECT_EQ(StorageTypeFromSeekPenalty(true, true), "hdd");
  EXPECT_EQ(StorageTypeFromSeekPenalty(false, false), "");
}

TEST(Helpers, SelectNetworkPrefersBestPhysical) {
  std::vector<NetworkCandidate> candidates;
  NetworkCandidate wifi;
  wifi.if_index = 10;
  wifi.ipv4 = "192.168.1.10";
  wifi.mac = "aa:bb:cc:dd:ee:ff";
  wifi.if_type = 71;
  wifi.is_up = true;
  wifi.ipv4_metric = 25;
  candidates.push_back(wifi);

  NetworkCandidate eth;
  eth.if_index = 12;
  eth.ipv4 = "10.0.0.5";
  eth.mac = "11:22:33:44:55:66";
  eth.if_type = 6;
  eth.is_up = true;
  eth.ipv4_metric = 10;
  candidates.push_back(eth);

  NetworkCandidate virt;
  virt.if_index = 20;
  virt.ipv4 = "172.20.0.2";
  virt.mac = "00:15:5d:00:00:01";
  virt.if_type = 6;
  virt.description = "vEthernet (WSL)";
  virt.is_up = true;
  virt.ipv4_metric = 5;
  candidates.push_back(virt);

  NetworkCandidate linklocal;
  linklocal.if_index = 30;
  linklocal.ipv4 = "169.254.3.4";
  linklocal.if_type = 6;
  linklocal.is_up = true;
  candidates.push_back(linklocal);

  // Best interface is ethernet -> use it for ip/mac/type together.
  auto sel = SelectNetwork(candidates, 12);
  EXPECT_TRUE(sel.found);
  EXPECT_EQ(sel.ipv4, "10.0.0.5");
  EXPECT_EQ(sel.mac, "11:22:33:44:55:66");
  EXPECT_EQ(sel.type, "ethernet");

  // No best index: prefer physical with lowest metric (eth metric 10 < wifi 25),
  // and never pick the virtual Hyper-V adapter even with better metric.
  sel = SelectNetwork(candidates, 0);
  EXPECT_TRUE(sel.found);
  EXPECT_EQ(sel.ipv4, "10.0.0.5");
  EXPECT_EQ(sel.type, "ethernet");
}


TEST(Helpers, SelectNetworkPhysicalBeatsBestVirtual) {
  std::vector<NetworkCandidate> candidates;
  NetworkCandidate wifi;
  wifi.if_index = 5;
  wifi.ipv4 = "192.168.1.133";
  wifi.mac = "2c:db:07:f1:c4:6c";
  wifi.if_type = 71;
  wifi.is_up = true;
  wifi.ipv4_metric = 35;
  candidates.push_back(wifi);

  NetworkCandidate meta;
  meta.if_index = 4;
  meta.ipv4 = "198.18.0.1";
  meta.if_type = 131;
  meta.description = "Meta Tunnel";
  meta.is_up = true;
  meta.ipv4_metric = 0;
  candidates.push_back(meta);

  // Best route is the Meta tunnel (index 4), but IP is fake-IP and virtual.
  auto sel = SelectNetwork(candidates, 4);
  EXPECT_TRUE(sel.found);
  EXPECT_EQ(sel.ipv4, "192.168.1.133");
  EXPECT_EQ(sel.mac, "2c:db:07:f1:c4:6c");
  EXPECT_EQ(sel.type, "wifi");
}

TEST(Helpers, SelectNetworkNoneOrUnknown) {
  auto none = SelectNetwork({});
  EXPECT_FALSE(none.found);
  EXPECT_EQ(none.type, "none");

  NetworkCandidate up_no_ip;
  up_no_ip.if_index = 1;
  up_no_ip.is_up = true;
  up_no_ip.if_type = 6;
  auto unknown = SelectNetwork({up_no_ip});
  EXPECT_FALSE(unknown.found);
  EXPECT_EQ(unknown.type, "unknown");
}

TEST(PluginSmoke, GetDeviceInfoReturnsMap) {
  // Kept in plugin_test; this file focuses on pure helpers.
  SUCCEED();
}

}  // namespace test
}  // namespace xue_hua_device_info
