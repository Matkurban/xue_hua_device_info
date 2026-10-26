// Pure (Win32-free where possible) helpers used by the Windows plugin.
#ifndef XUE_HUA_DEVICE_INFO_HELPERS_H_
#define XUE_HUA_DEVICE_INFO_HELPERS_H_

#include <cstdint>
#include <string>
#include <vector>

namespace xue_hua_device_info {

// Trim trailing/leading ASCII whitespace and CR/LF.
std::string Trim(const std::string& value);

// Drop known BIOS/OEM placeholders (case-insensitive). Empty after trim -> "".
std::string SanitizeHardwareString(std::string value);

// RFC 3927 link-local 169.254.0.0/16 (and empty / 127.* are not "usable").
bool IsLinkLocalIpv4(const std::string& ipv4);
bool IsLoopbackIpv4(const std::string& ipv4);
// RFC 2544 benchmarking range 198.18.0.0/15, commonly used by local
// proxy/VPN fake-IP stacks (Clash Meta, Surge, etc.).
bool IsProxyFakeIpv4(const std::string& ipv4);
bool IsUsableIpv4(const std::string& ipv4);

// Map IANA IfType (+ optional description hints) to wifi/ethernet/unknown.
// Virtual/tunnel/PPP adapters are marked virtual so selection can deprioritize.
enum class AdapterKind { kWifi, kEthernet, kVirtual, kOther };

struct AdapterKindResult {
  AdapterKind kind = AdapterKind::kOther;
  std::string type_string;  // "wifi" | "ethernet" | "unknown"
};

// if_type values match Ipifcons.h / IANA (IF_TYPE_ETHERNET_CSMACD=6,
// IF_TYPE_IEEE80211=71, IF_TYPE_SOFTWARE_LOOPBACK=24, IF_TYPE_TUNNEL=131,
// IF_TYPE_PPP=23, IF_TYPE_PROP_VIRTUAL=53).
AdapterKindResult ClassifyAdapter(unsigned long if_type,
                                  const std::string& description_utf8 = "");

struct NetworkCandidate {
  unsigned long if_index = 0;
  std::string ipv4;
  std::string mac;  // already formatted "aa:bb:..." or ""
  unsigned long if_type = 0;
  std::string description;
  bool is_up = false;
  bool is_loopback = false;
  // Ipv4InterfaceMetric from IP_ADAPTER_ADDRESSES (lower is preferred).
  unsigned long ipv4_metric = 0xffffffffu;
};

struct NetworkSelection {
  bool found = false;
  std::string ipv4;
  std::string mac;
  std::string type;  // "wifi" | "ethernet" | "unknown" | "none"
};

// Pick ONE up, non-loopback adapter with a usable IPv4. Preference:
//   1) match best_if_index (from GetBestInterfaceEx) when usable
//   2) physical wifi/ethernet by lowest ipv4_metric
//   3) other physical
//   4) virtual (tunnel/PPP/prop_virtual) last
// IP, MAC and type all come from the same adapter.
NetworkSelection SelectNetwork(const std::vector<NetworkCandidate>& candidates,
                               unsigned long best_if_index = 0);

// Map DEVICE_SEEK_PENALTY_DESCRIPTOR.IncursSeekPenalty to storageType.
// true -> "hdd", false -> "ssd". When query_ok is false, returns "".
std::string StorageTypeFromSeekPenalty(bool query_ok, bool incurs_seek_penalty);

// Format 6-byte MAC as lowercase colon-separated hex. "" if length != 6 or
// all zeros.
std::string FormatMac(const unsigned char* bytes, size_t length);

}  // namespace xue_hua_device_info

#endif  // XUE_HUA_DEVICE_INFO_HELPERS_H_
