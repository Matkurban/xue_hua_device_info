#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
// Winsock2 must be included before windows.h, including Flutter headers that
// pull windows.h in.
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>

#include "xue_hua_device_info_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cctype>
#include <cstdio>
#include <memory>
#include <string>
#include <vector>

namespace xue_hua_device_info {

namespace {

flutter::EncodableMap MakeMap(
    std::initializer_list<std::pair<std::string, flutter::EncodableValue>>
        entries) {
  flutter::EncodableMap map;
  for (const auto &entry : entries) {
    map[flutter::EncodableValue(entry.first)] = entry.second;
  }
  return map;
}

std::string WideToUtf8(const std::wstring &wide) {
  if (wide.empty()) {
    return {};
  }
  int size =
      WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0, nullptr,
                          nullptr);
  if (size <= 1) {
    return {};
  }
  std::string result(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, result.data(), size,
                      nullptr, nullptr);
  return result;
}

std::wstring ReadRegistryString(HKEY root, const wchar_t *sub_key,
                                const wchar_t *value_name) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(root, sub_key, 0, KEY_READ, &key) != ERROR_SUCCESS) {
    return {};
  }
  DWORD type = 0;
  DWORD size = 0;
  if (RegQueryValueExW(key, value_name, nullptr, &type, nullptr, &size) !=
          ERROR_SUCCESS ||
      type != REG_SZ || size == 0) {
    RegCloseKey(key);
    return {};
  }
  std::wstring value(size / sizeof(wchar_t), L'\0');
  if (RegQueryValueExW(key, value_name, nullptr, &type,
                       reinterpret_cast<LPBYTE>(value.data()),
                       &size) != ERROR_SUCCESS) {
    RegCloseKey(key);
    return {};
  }
  RegCloseKey(key);
  while (!value.empty() && value.back() == L'\0') {
    value.pop_back();
  }
  return value;
}

flutter::EncodableValue NullOrString(const std::string &value) {
  if (value.empty()) {
    return flutter::EncodableValue();
  }
  return flutter::EncodableValue(value);
}

std::string SanitizeHardwareString(std::string value) {
  // Trim
  while (!value.empty() &&
         (value.back() == ' ' || value.back() == '\n' || value.back() == '\r')) {
    value.pop_back();
  }
  if (value.empty()) {
    return {};
  }
  std::string lower = value;
  for (auto &ch : lower) {
    ch = static_cast<char>(::tolower(static_cast<unsigned char>(ch)));
  }
  if (lower == "none" || lower == "default string" ||
      lower == "to be filled by o.e.m." || lower == "system serial number" ||
      lower == "o.e.m." || lower == "oem") {
    return {};
  }
  return value;
}

flutter::EncodableMap GetDeviceInfo() {
  const auto manufacturer = SanitizeHardwareString(WideToUtf8(ReadRegistryString(
      HKEY_LOCAL_MACHINE, L"HARDWARE\\DESCRIPTION\\System\\BIOS",
      L"SystemManufacturer")));
  const auto model = SanitizeHardwareString(WideToUtf8(ReadRegistryString(
      HKEY_LOCAL_MACHINE, L"HARDWARE\\DESCRIPTION\\System\\BIOS",
      L"SystemProductName")));
  const auto serial = SanitizeHardwareString(WideToUtf8(ReadRegistryString(
      HKEY_LOCAL_MACHINE, L"HARDWARE\\DESCRIPTION\\System\\BIOS",
      L"SystemSerialNumber")));
  const auto uuid = WideToUtf8(ReadRegistryString(
      HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Microsoft\\Cryptography", L"MachineGuid"));

  wchar_t computer_name[MAX_COMPUTERNAME_LENGTH + 1] = {};
  DWORD name_size = MAX_COMPUTERNAME_LENGTH + 1;
  std::string name;
  if (GetComputerNameW(computer_name, &name_size)) {
    name = WideToUtf8(computer_name);
  }

  return MakeMap({
      {"deviceId", NullOrString(uuid)},
      {"manufacturer", NullOrString(manufacturer)},
      {"model", NullOrString(model)},
      {"serial", NullOrString(serial)},
      {"name", NullOrString(name)},
  });
}

flutter::EncodableMap GetBatteryInfo() {
  SYSTEM_POWER_STATUS status = {};
  if (!GetSystemPowerStatus(&status) || status.BatteryFlag == 128) {
    return MakeMap({
        {"level", flutter::EncodableValue()},
        {"isCharging", flutter::EncodableValue()},
        {"health", flutter::EncodableValue()},
    });
  }

  flutter::EncodableValue level;
  if (status.BatteryLifePercent != 255) {
    level = flutter::EncodableValue(
        static_cast<double>(status.BatteryLifePercent));
  }
  // BATTERY_FLAG_CHARGING == 8. Do not treat "on AC" alone as charging
  // (full battery while plugged in should report false).
  const bool is_charging = (status.BatteryFlag & 8) != 0;
  return MakeMap({
      {"level", level},
      {"isCharging", flutter::EncodableValue(is_charging)},
      {"health", flutter::EncodableValue()},
  });
}

std::string LocalIpv4() {
  ULONG size = 0;
  GetAdaptersAddresses(AF_INET, GAA_FLAG_INCLUDE_PREFIX, nullptr, nullptr,
                       &size);
  if (size == 0) {
    return {};
  }
  std::vector<unsigned char> buffer(size);
  auto *addresses =
      reinterpret_cast<IP_ADAPTER_ADDRESSES *>(buffer.data());
  if (GetAdaptersAddresses(AF_INET, GAA_FLAG_INCLUDE_PREFIX, nullptr,
                           addresses, &size) != NO_ERROR) {
    return {};
  }
  for (auto *adapter = addresses; adapter != nullptr;
       adapter = adapter->Next) {
    if (adapter->OperStatus != IfOperStatusUp ||
        adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK) {
      continue;
    }
    for (auto *unicast = adapter->FirstUnicastAddress; unicast != nullptr;
         unicast = unicast->Next) {
      auto *addr = reinterpret_cast<sockaddr_in *>(unicast->Address.lpSockaddr);
      char ip[INET_ADDRSTRLEN] = {};
      inet_ntop(AF_INET, &(addr->sin_addr), ip, INET_ADDRSTRLEN);
      std::string candidate(ip);
      if (!candidate.empty() && candidate.rfind("127.", 0) != 0) {
        return candidate;
      }
    }
  }
  return {};
}

std::string NetworkType() {
  ULONG size = 0;
  GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr, nullptr,
                       &size);
  if (size == 0) {
    return "none";
  }
  std::vector<unsigned char> buffer(size);
  auto *addresses =
      reinterpret_cast<IP_ADAPTER_ADDRESSES *>(buffer.data());
  if (GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr,
                           addresses, &size) != NO_ERROR) {
    return "unknown";
  }
  bool has_up = false;
  for (auto *adapter = addresses; adapter != nullptr;
       adapter = adapter->Next) {
    if (adapter->OperStatus != IfOperStatusUp ||
        adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK) {
      continue;
    }
    has_up = true;
    if (adapter->IfType == IF_TYPE_IEEE80211) {
      return "wifi";
    }
    if (adapter->IfType == IF_TYPE_ETHERNET_CSMACD) {
      return "ethernet";
    }
  }
  return has_up ? "unknown" : "none";
}

std::string PrimaryMac() {
  ULONG size = 0;
  GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr, nullptr,
                       &size);
  if (size == 0) {
    return {};
  }
  std::vector<unsigned char> buffer(size);
  auto *addresses =
      reinterpret_cast<IP_ADAPTER_ADDRESSES *>(buffer.data());
  if (GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr,
                           addresses, &size) != NO_ERROR) {
    return {};
  }
  for (auto *adapter = addresses; adapter != nullptr;
       adapter = adapter->Next) {
    if (adapter->OperStatus != IfOperStatusUp ||
        adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK ||
        adapter->PhysicalAddressLength != 6) {
      continue;
    }
    char mac[32] = {};
    snprintf(mac, sizeof(mac), "%02x:%02x:%02x:%02x:%02x:%02x",
             adapter->PhysicalAddress[0], adapter->PhysicalAddress[1],
             adapter->PhysicalAddress[2], adapter->PhysicalAddress[3],
             adapter->PhysicalAddress[4], adapter->PhysicalAddress[5]);
    return mac;
  }
  return {};
}

flutter::EncodableMap GetNetworkInfo() {
  return MakeMap({
      {"ipAddress", NullOrString(LocalIpv4())},
      {"networkType", flutter::EncodableValue(NetworkType())},
      {"macAddress", NullOrString(PrimaryMac())},
  });
}

flutter::EncodableMap GetStorageInfo() {
  wchar_t windows_dir[MAX_PATH] = {};
  std::wstring root = L"C:\\";
  if (GetWindowsDirectoryW(windows_dir, MAX_PATH) > 0 && windows_dir[0] != L'\0') {
    root = std::wstring(1, windows_dir[0]) + L":\\";
  }

  ULARGE_INTEGER free_bytes = {};
  ULARGE_INTEGER total_bytes = {};
  if (!GetDiskFreeSpaceExW(root.c_str(), &free_bytes, &total_bytes, nullptr)) {
    return MakeMap({
        {"totalBytes", flutter::EncodableValue(0)},
        {"freeBytes", flutter::EncodableValue(0)},
        {"storageType", flutter::EncodableValue()},
    });
  }
  return MakeMap({
      {"totalBytes",
       flutter::EncodableValue(static_cast<int64_t>(total_bytes.QuadPart))},
      {"freeBytes",
       flutter::EncodableValue(static_cast<int64_t>(free_bytes.QuadPart))},
      {"storageType", flutter::EncodableValue()},
  });
}

flutter::EncodableMap GetDisplayInfo() {
  const int width = GetSystemMetrics(SM_CXSCREEN);
  const int height = GetSystemMetrics(SM_CYSCREEN);
  double scale = 1.0;
  HDC hdc = GetDC(nullptr);
  if (hdc != nullptr) {
    const int dpi = GetDeviceCaps(hdc, LOGPIXELSX);
    scale = static_cast<double>(dpi) / 96.0;
    ReleaseDC(nullptr, hdc);
  }

  DEVMODEW mode = {};
  mode.dmSize = sizeof(mode);
  flutter::EncodableValue refresh;
  if (EnumDisplaySettingsW(nullptr, ENUM_CURRENT_SETTINGS, &mode) &&
      mode.dmDisplayFrequency > 1) {
    refresh =
        flutter::EncodableValue(static_cast<double>(mode.dmDisplayFrequency));
  }

  return MakeMap({
      {"width", flutter::EncodableValue(width)},
      {"height", flutter::EncodableValue(height)},
      {"scaleFactor", flutter::EncodableValue(scale)},
      {"refreshRate", refresh},
  });
}

}  // namespace

// static
void XueHuaDeviceInfoPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "xue_hua_device_info",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<XueHuaDeviceInfoPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

XueHuaDeviceInfoPlugin::XueHuaDeviceInfoPlugin() {}

XueHuaDeviceInfoPlugin::~XueHuaDeviceInfoPlugin() {}

void XueHuaDeviceInfoPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto &method = method_call.method_name();
  if (method == "getDeviceInfo") {
    result->Success(flutter::EncodableValue(GetDeviceInfo()));
  } else if (method == "getBatteryInfo") {
    result->Success(flutter::EncodableValue(GetBatteryInfo()));
  } else if (method == "getNetworkInfo") {
    result->Success(flutter::EncodableValue(GetNetworkInfo()));
  } else if (method == "getStorageInfo") {
    result->Success(flutter::EncodableValue(GetStorageInfo()));
  } else if (method == "getDisplayInfo") {
    result->Success(flutter::EncodableValue(GetDisplayInfo()));
  } else {
    result->NotImplemented();
  }
}

}  // namespace xue_hua_device_info
