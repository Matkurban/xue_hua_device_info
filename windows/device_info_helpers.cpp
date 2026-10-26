#include "device_info_helpers.h"

#include <algorithm>
#include <cctype>
#include <cstdio>

namespace xue_hua_device_info {

namespace {

constexpr unsigned long kIfTypeOther = 1;
constexpr unsigned long kIfTypeEthernetCsmacd = 6;
constexpr unsigned long kIfTypePpp = 23;
constexpr unsigned long kIfTypeSoftwareLoopback = 24;
constexpr unsigned long kIfTypeIeee80211 = 71;
constexpr unsigned long kIfTypeTunnel = 131;
constexpr unsigned long kIfTypePropVirtual = 53;

std::string ToLowerCopy(std::string value) {
  for (auto& ch : value) {
    ch = static_cast<char>(
        ::tolower(static_cast<unsigned char>(ch)));
  }
  return value;
}

bool DescriptionSuggestsVirtual(const std::string& description_utf8) {
  const std::string lower = ToLowerCopy(description_utf8);
  // Common Windows virtual/tunnel adapters (Hyper-V, VPN, WSL, Docker, etc.).
  static const char* kHints[] = {
      "virtual", "hyper-v", "vethernet", "vpn", "tap-", "tun", "wsl",
      "docker", "npcap", "loopback", "teredo", "isatap", "6to4",
      "bluetooth network",
  };
  for (const char* hint : kHints) {
    if (lower.find(hint) != std::string::npos) {
      return true;
    }
  }
  return false;
}

}  // namespace

std::string Trim(const std::string& value) {
  size_t start = 0;
  while (start < value.size() &&
         (value[start] == ' ' || value[start] == '\t' || value[start] == '\n' ||
          value[start] == '\r')) {
    ++start;
  }
  size_t end = value.size();
  while (end > start && (value[end - 1] == ' ' || value[end - 1] == '\t' ||
                         value[end - 1] == '\n' || value[end - 1] == '\r')) {
    --end;
  }
  return value.substr(start, end - start);
}

std::string SanitizeHardwareString(std::string value) {
  value = Trim(value);
  if (value.empty()) {
    return {};
  }
  const std::string lower = ToLowerCopy(value);
  if (lower == "none" || lower == "default string" ||
      lower == "to be filled by o.e.m." || lower == "system serial number" ||
      lower == "o.e.m." || lower == "oem" || lower == "system product name" ||
      lower == "system manufacturer") {
    return {};
  }
  return value;
}

bool IsLinkLocalIpv4(const std::string& ipv4) {
  return ipv4.rfind("169.254.", 0) == 0;
}

bool IsLoopbackIpv4(const std::string& ipv4) {
  return ipv4.rfind("127.", 0) == 0;
}

bool IsProxyFakeIpv4(const std::string& ipv4) {
  // 198.18.0.0/15 => first octet 198, second 18 or 19.
  if (ipv4.rfind("198.18.", 0) == 0 || ipv4.rfind("198.19.", 0) == 0) {
    return true;
  }
  return false;
}

bool IsUsableIpv4(const std::string& ipv4) {
  return !ipv4.empty() && !IsLoopbackIpv4(ipv4) && !IsLinkLocalIpv4(ipv4) &&
         !IsProxyFakeIpv4(ipv4);
}

AdapterKindResult ClassifyAdapter(unsigned long if_type,
                                  const std::string& description_utf8) {
  AdapterKindResult result;
  if (if_type == kIfTypeSoftwareLoopback) {
    result.kind = AdapterKind::kOther;
    result.type_string = "unknown";
    return result;
  }
  if (if_type == kIfTypeTunnel || if_type == kIfTypePpp ||
      if_type == kIfTypePropVirtual ||
      DescriptionSuggestsVirtual(description_utf8)) {
    result.kind = AdapterKind::kVirtual;
    // Tunnel/VPN often still carries traffic; type stays unknown unless wifi/eth.
    result.type_string = "unknown";
    return result;
  }
  if (if_type == kIfTypeIeee80211) {
    result.kind = AdapterKind::kWifi;
    result.type_string = "wifi";
    return result;
  }
  if (if_type == kIfTypeEthernetCsmacd) {
    result.kind = AdapterKind::kEthernet;
    result.type_string = "ethernet";
    return result;
  }
  if (if_type == kIfTypeOther) {
    result.kind = AdapterKind::kOther;
    result.type_string = "unknown";
    return result;
  }
  result.kind = AdapterKind::kOther;
  result.type_string = "unknown";
  return result;
}

std::string FormatMac(const unsigned char* bytes, size_t length) {
  if (bytes == nullptr || length != 6) {
    return {};
  }
  bool all_zero = true;
  for (size_t i = 0; i < length; ++i) {
    if (bytes[i] != 0) {
      all_zero = false;
      break;
    }
  }
  if (all_zero) {
    return {};
  }
  char mac[32] = {};
  std::snprintf(mac, sizeof(mac), "%02x:%02x:%02x:%02x:%02x:%02x", bytes[0],
                bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]);
  return mac;
}

std::string StorageTypeFromSeekPenalty(bool query_ok,
                                       bool incurs_seek_penalty) {
  if (!query_ok) {
    return {};
  }
  return incurs_seek_penalty ? "hdd" : "ssd";
}

NetworkSelection SelectNetwork(const std::vector<NetworkCandidate>& candidates,
                               unsigned long best_if_index) {
  NetworkSelection none;
  none.type = "none";

  struct Scored {
    const NetworkCandidate* c = nullptr;
    int tier = 100;
  };
  std::vector<Scored> scored;
  scored.reserve(candidates.size());

  bool any_up = false;
  for (const auto& c : candidates) {
    if (c.is_loopback || !c.is_up) {
      continue;
    }
    any_up = true;
    if (!IsUsableIpv4(c.ipv4)) {
      continue;
    }
    const auto kind = ClassifyAdapter(c.if_type, c.description);
    // Lower tier wins. Physical adapters always beat virtual/tunnel even when
    // GetBestInterfaceEx points at a VPN/proxy TUN (Clash Meta, etc.).
    const bool is_best = best_if_index != 0 && c.if_index == best_if_index;
    const bool is_physical = kind.kind == AdapterKind::kWifi ||
                             kind.kind == AdapterKind::kEthernet;
    int tier = 50;
    if (is_physical && is_best) {
      tier = 0;
    } else if (is_physical) {
      tier = 20;
    } else if (kind.kind == AdapterKind::kVirtual && is_best) {
      tier = 60;
    } else if (kind.kind == AdapterKind::kVirtual) {
      tier = 80;
    } else if (is_best) {
      tier = 30;
    } else {
      tier = 40;
    }
    scored.push_back(Scored{&c, tier});
  }

  if (scored.empty()) {
    none.type = any_up ? "unknown" : "none";
    return none;
  }

  std::stable_sort(scored.begin(), scored.end(),
                   [](const Scored& a, const Scored& b) {
                     if (a.tier != b.tier) {
                       return a.tier < b.tier;
                     }
                     return a.c->ipv4_metric < b.c->ipv4_metric;
                   });

  const NetworkCandidate& best = *scored.front().c;
  const auto kind = ClassifyAdapter(best.if_type, best.description);
  NetworkSelection selection;
  selection.found = true;
  selection.ipv4 = best.ipv4;
  selection.mac = best.mac;
  selection.type = kind.type_string;
  return selection;
}

}  // namespace xue_hua_device_info
