// Pure (GTK/Flutter-free) helpers used by the Linux plugin. Every function that
// touches the filesystem accepts a `root` prefix (default: "") so unit tests
// can point it at a fake sysfs/etc tree.
#ifndef XUE_HUA_DEVICE_INFO_HELPERS_H_
#define XUE_HUA_DEVICE_INFO_HELPERS_H_

#include <string>
#include <vector>

namespace xue_hua_device_info {

// Strips trailing/leading whitespace and newlines.
std::string Trim(const std::string& value);

// Reads a small text file, trimmed. Returns "" when missing/unreadable or when
// the content is a known placeholder ("None", "To be filled by O.E.M.", ...).
std::string ReadTrimmedFile(const std::string& path);

// False for empty, "uninitialized" (machine-id first boot) and all-zero /
// all-F placeholder ids.
bool IsUsableId(const std::string& id);

// Device id: DMI product_uuid when readable (usually root only), otherwise
// /etc/machine-id, otherwise /var/lib/dbus/machine-id. "" if none available.
std::string ResolveDeviceId(const std::string& root = "");

struct BatteryReading {
  bool found = false;        // A usable battery with a valid capacity exists.
  double level = 0.0;        // 0..100
  bool is_charging = false;  // status is Charging or Full
  std::string health;        // `health` file content, "" when unavailable
};

// Scans <root>/sys/class/power_supply/* for type == Battery (skipping
// scope == Device, e.g. wireless mice) and reads the first one with a valid
// capacity (entries are visited in sorted order).
BatteryReading ReadBattery(const std::string& root = "");

enum class InterfaceKind { kWifi, kEthernet, kVirtual, kOther };

// Classifies an interface using <root>/sys/class/net/<name>/{wireless,device,
// bridge,tun_flags,...} and well-known name prefixes.
InterfaceKind ClassifyInterface(const std::string& name,
                                const std::string& root = "");

struct NetworkCandidate {
  std::string name;
  std::string ipv4;
  bool is_up = false;
  bool is_loopback = false;
};

// Returns the interface name of the default IPv4 route (lowest metric) from
// the content of /proc/net/route, or "".
std::string ParseDefaultRouteInterface(const std::string& proc_net_route);

struct NetworkSelection {
  bool found = false;
  std::string name;
  std::string ipv4;
  std::string mac;
  std::string type;  // "wifi" | "ethernet" | "unknown"
};

// Picks ONE interface (up, non-loopback, has IPv4) and derives ip/mac/type from
// it. Preference: physical default-route > other physical > virtual default-route
// > other virtual (docker, veth, bridge, tun...).
NetworkSelection SelectNetwork(const std::vector<NetworkCandidate>& candidates,
                               const std::string& default_route_iface,
                               const std::string& root = "");

}  // namespace xue_hua_device_info

#endif  // XUE_HUA_DEVICE_INFO_HELPERS_H_
