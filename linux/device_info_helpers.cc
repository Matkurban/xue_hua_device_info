#include "device_info_helpers.h"

#include <dirent.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <sstream>

namespace xue_hua_device_info {

namespace {

bool PathExists(const std::string& path) {
  struct stat st;
  return stat(path.c_str(), &st) == 0;
}

bool StartsWith(const std::string& value, const char* prefix) {
  return value.rfind(prefix, 0) == 0;
}

std::vector<std::string> ListDir(const std::string& path) {
  std::vector<std::string> names;
  DIR* dir = opendir(path.c_str());
  if (dir == nullptr) {
    return names;
  }
  while (struct dirent* entry = readdir(dir)) {
    std::string name = entry->d_name;
    if (name != "." && name != "..") {
      names.push_back(name);
    }
  }
  closedir(dir);
  std::sort(names.begin(), names.end());
  return names;
}

bool IsVirtualName(const std::string& name) {
  static const char* const kPrefixes[] = {
      "docker", "veth", "br-", "br0", "virbr", "vmnet", "vboxnet", "tun",
      "tap",    "wg",   "tailscale", "zt", "lxc", "lxd", "cni", "flannel",
      "cali",   "dummy", "ifb", "macvtap", "podman", "vnet"};
  for (const char* prefix : kPrefixes) {
    if (StartsWith(name, prefix)) {
      return true;
    }
  }
  return false;
}

}  // namespace

std::string Trim(const std::string& value) {
  const char* ws = " \t\r\n";
  const size_t begin = value.find_first_not_of(ws);
  if (begin == std::string::npos) {
    return {};
  }
  const size_t end = value.find_last_not_of(ws);
  return value.substr(begin, end - begin + 1);
}

std::string ReadTrimmedFile(const std::string& path) {
  std::ifstream input(path);
  if (!input.is_open()) {
    return {};
  }
  std::stringstream buffer;
  buffer << input.rdbuf();
  std::string value = Trim(buffer.str());
  if (value == "None" || value == "To be filled by O.E.M." ||
      value == "Default string" || value == "System Serial Number") {
    return {};
  }
  return value;
}

// machine-id(5): the file holds 32 lowercase hex chars; it may contain
// "uninitialized" on first boot, must not be all zeros. DMI UUIDs of
// 00000000-... / FFFFFFFF-... are firmware placeholders.
bool IsUsableId(const std::string& id) {
  if (id.empty() || id == "uninitialized") {
    return false;
  }
  bool all_zero = true;
  bool all_f = true;
  for (char ch : id) {
    if (ch == '-') continue;
    if (ch != '0') all_zero = false;
    if (ch != 'f' && ch != 'F') all_f = false;
  }
  return !all_zero && !all_f;
}

std::string ResolveDeviceId(const std::string& root) {
  static const char* const kSources[] = {
      "/sys/class/dmi/id/product_uuid",
      "/etc/machine-id",
      "/var/lib/dbus/machine-id",
  };
  for (const char* source : kSources) {
    std::string id = ReadTrimmedFile(root + source);
    if (IsUsableId(id)) {
      return id;
    }
  }
  return {};
}

BatteryReading ReadBattery(const std::string& root) {
  const std::string base = root + "/sys/class/power_supply/";
  for (const std::string& name : ListDir(base)) {
    const std::string dir = base + name + "/";
    if (ReadTrimmedFile(dir + "type") != "Battery") {
      continue;
    }
    if (ReadTrimmedFile(dir + "scope") == "Device") {
      continue;
    }
    // `present` is optional; when absent the battery is considered present.
    if (ReadTrimmedFile(dir + "present") == "0") {
      continue;
    }
    const std::string capacity = ReadTrimmedFile(dir + "capacity");
    if (capacity.empty()) {
      continue;
    }
    char* end = nullptr;
    const double parsed = std::strtod(capacity.c_str(), &end);
    if (end == capacity.c_str() || parsed < 0.0 || parsed > 100.0) {
      continue;
    }
    BatteryReading reading;
    reading.found = true;
    reading.level = parsed;
    const std::string status = ReadTrimmedFile(dir + "status");
    reading.is_charging = status == "Charging" || status == "Full";
    reading.health = ReadTrimmedFile(dir + "health");
    if (reading.health == "Unknown") {
      reading.health.clear();
    }
    return reading;
  }
  return {};
}

InterfaceKind ClassifyInterface(const std::string& name,
                                const std::string& root) {
  const std::string dir = root + "/sys/class/net/" + name;
  if (PathExists(dir + "/wireless") || PathExists(dir + "/phy80211")) {
    return InterfaceKind::kWifi;
  }
  // Bonding masters carry traffic for real NICs; treat as ethernet.
  if (PathExists(dir + "/bonding") || StartsWith(name, "bond")) {
    return InterfaceKind::kEthernet;
  }
  if (PathExists(dir + "/bridge") || PathExists(dir + "/tun_flags") ||
      IsVirtualName(name)) {
    return InterfaceKind::kVirtual;
  }
  if (StartsWith(name, "wl")) {
    return InterfaceKind::kWifi;
  }
  if (StartsWith(name, "eth") || StartsWith(name, "en") ||
      StartsWith(name, "eno") || StartsWith(name, "ens") ||
      StartsWith(name, "enp")) {
    return InterfaceKind::kEthernet;
  }
  return InterfaceKind::kOther;
}

std::string ParseDefaultRouteInterface(const std::string& proc_net_route) {
  std::istringstream lines(proc_net_route);
  std::string line;
  std::getline(lines, line);  // header
  std::string best;
  long best_metric = -1;
  while (std::getline(lines, line)) {
    std::istringstream fields(line);
    std::string iface, destination, gateway, flags, refcnt, use, metric, mask;
    if (!(fields >> iface >> destination >> gateway >> flags >> refcnt >> use >>
          metric >> mask)) {
      continue;
    }
    // Columns: Iface Destination Gateway Flags RefCnt Use Metric Mask ...
    // Addresses are little-endian hex; flags are hex; metric is decimal.
    if (destination != "00000000" || mask != "00000000") {
      continue;
    }
    const long flag_bits = std::strtol(flags.c_str(), nullptr, 16);
    if ((flag_bits & 0x1) == 0) {  // RTF_UP
      continue;
    }
    const long m = std::strtol(metric.c_str(), nullptr, 10);
    if (best_metric < 0 || m < best_metric) {
      best_metric = m;
      best = iface;
    }
  }
  return best;
}

NetworkSelection SelectNetwork(const std::vector<NetworkCandidate>& candidates,
                               const std::string& default_route_iface,
                               const std::string& root) {
  const NetworkCandidate* best = nullptr;
  int best_score = -1;
  InterfaceKind best_kind = InterfaceKind::kOther;
  for (const NetworkCandidate& c : candidates) {
    if (!c.is_up || c.is_loopback || c.name == "lo" || c.ipv4.empty() ||
        StartsWith(c.ipv4, "127.")) {
      continue;
    }
    const InterfaceKind kind = ClassifyInterface(c.name, root);
    const bool physical = kind != InterfaceKind::kVirtual;
    const bool is_default = !default_route_iface.empty() &&
                            c.name == default_route_iface;
    const bool link_local = StartsWith(c.ipv4, "169.254.");
    int score = 0;
    if (physical) score += 8;
    if (is_default) score += 4;
    if (kind == InterfaceKind::kWifi || kind == InterfaceKind::kEthernet) {
      score += 1;
    }
    // RFC 3927 link-local addresses are last-resort; prefer routable IPs.
    if (link_local) score -= 16;
    if (score > best_score) {  // first wins on ties (stable order)
      best_score = score;
      best = &c;
      best_kind = kind;
    }
  }
  NetworkSelection result;
  if (best == nullptr) {
    return result;
  }
  result.found = true;
  result.name = best->name;
  result.ipv4 = best->ipv4;
  const std::string mac =
      ReadTrimmedFile(root + "/sys/class/net/" + best->name + "/address");
  if (mac != "00:00:00:00:00:00") {
    result.mac = mac;
  }
  switch (best_kind) {
    case InterfaceKind::kWifi:
      result.type = "wifi";
      break;
    case InterfaceKind::kEthernet:
      result.type = "ethernet";
      break;
    default:
      result.type = "unknown";
      break;
  }
  return result;
}


std::string ResolveStorageTypeFromDev(unsigned major_num, unsigned minor_num,
                                      const std::string& root) {
  if (major_num == 0) {
    return {};
  }
  const std::string base =
      root + "/sys/dev/block/" + std::to_string(major_num) + ":" +
      std::to_string(minor_num);
  // Prefer this node's queue; partitions often inherit via a sibling path.
  std::string rotational = ReadTrimmedFile(base + "/queue/rotational");
  if (rotational.empty()) {
    // Partition nodes expose a `partition` file; parent disk is `..`.
    if (PathExists(base + "/partition")) {
      rotational = ReadTrimmedFile(base + "/../queue/rotational");
      if (rotational.empty()) {
        const std::string parent_dev = ReadTrimmedFile(base + "/../dev");
        if (!parent_dev.empty()) {
          rotational = ReadTrimmedFile(root + "/sys/dev/block/" + parent_dev +
                                       "/queue/rotational");
        }
      }
    }
  }
  // Device-mapper / stacked devices: inspect the first slave when present.
  if (rotational.empty()) {
    const std::string slaves = base + "/slaves";
    for (const std::string& slave : ListDir(slaves)) {
      rotational = ReadTrimmedFile(root + "/sys/block/" + slave +
                                   "/queue/rotational");
      if (!rotational.empty()) {
        break;
      }
    }
  }
  if (rotational == "0") {
    return "ssd";
  }
  if (rotational == "1") {
    return "hdd";
  }
  return {};
}

std::string ResolveStorageType(const std::string& path, const std::string& root) {
  struct stat st;
  // When `root` is set (unit tests), only the sysfs tree is faked; `path` is
  // still resolved against the real filesystem unless callers use
  // ResolveStorageTypeFromDev directly.
  if (stat(path.c_str(), &st) != 0) {
    return {};
  }
  return ResolveStorageTypeFromDev(major(st.st_dev), minor(st.st_dev), root);
}

}  // namespace xue_hua_device_info
