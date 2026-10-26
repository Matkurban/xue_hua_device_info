#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
// Winsock2 must be included before windows.h, including Flutter headers that
// pull windows.h in.
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <winioctl.h>

#include "xue_hua_device_info_plugin.h"

#include "device_info_helpers.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace xue_hua_device_info {

namespace {

flutter::EncodableMap MakeMap(
    std::initializer_list<std::pair<std::string, flutter::EncodableValue>>
        entries) {
  flutter::EncodableMap map;
  for (const auto& entry : entries) {
    map[flutter::EncodableValue(entry.first)] = entry.second;
  }
  return map;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return {};
  }
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0,
                                 nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string result(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, result.data(), size, nullptr,
                      nullptr);
  return result;
}

std::wstring ReadRegistryString(HKEY root, const wchar_t* sub_key,
                                const wchar_t* value_name) {
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

flutter::EncodableValue NullOrString(const std::string& value) {
  if (value.empty()) {
    return flutter::EncodableValue();
  }
  return flutter::EncodableValue(value);
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
      HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Cryptography", L"MachineGuid"));

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
    // No system battery (BatteryFlag bit 7 / 128).
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
  // GetSystemPowerStatus does not expose health; leave null (documented).
  return MakeMap({
      {"level", level},
      {"isCharging", flutter::EncodableValue(is_charging)},
      {"health", flutter::EncodableValue()},
  });
}

unsigned long BestIpv4InterfaceIndex() {
  // Prefer the interface Windows would use for a typical public IPv4 dest.
  sockaddr_in dest = {};
  dest.sin_family = AF_INET;
  // 1.1.1.1 - any public address works; we only need the interface index.
  inet_pton(AF_INET, "1.1.1.1", &dest.sin_addr);
  DWORD index = 0;
  if (GetBestInterfaceEx(reinterpret_cast<sockaddr*>(&dest), &index) ==
      NO_ERROR) {
    return index;
  }
  return 0;
}

std::vector<NetworkCandidate> CollectNetworkCandidates() {
  std::vector<NetworkCandidate> out;
  ULONG size = 0;
  GetAdaptersAddresses(AF_INET,
                       GAA_FLAG_INCLUDE_PREFIX | GAA_FLAG_INCLUDE_GATEWAYS,
                       nullptr, nullptr, &size);
  if (size == 0) {
    return out;
  }
  std::vector<unsigned char> buffer(size);
  auto* addresses = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
  if (GetAdaptersAddresses(AF_INET,
                           GAA_FLAG_INCLUDE_PREFIX | GAA_FLAG_INCLUDE_GATEWAYS,
                           nullptr, addresses, &size) != NO_ERROR) {
    return out;
  }
  for (auto* adapter = addresses; adapter != nullptr; adapter = adapter->Next) {
    NetworkCandidate candidate;
    candidate.if_index = adapter->IfIndex;
    candidate.if_type = adapter->IfType;
    candidate.is_up = adapter->OperStatus == IfOperStatusUp;
    candidate.is_loopback = adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK;
    candidate.ipv4_metric = adapter->Ipv4Metric;
    if (adapter->Description != nullptr) {
      candidate.description = WideToUtf8(adapter->Description);
    }
    if (adapter->PhysicalAddressLength == 6) {
      candidate.mac =
          FormatMac(adapter->PhysicalAddress, adapter->PhysicalAddressLength);
    }
    // Prefer first usable IPv4 on this adapter; fall back to any non-loopback.
    std::string fallback_ip;
    for (auto* unicast = adapter->FirstUnicastAddress; unicast != nullptr;
         unicast = unicast->Next) {
      if (unicast->Address.lpSockaddr == nullptr ||
          unicast->Address.lpSockaddr->sa_family != AF_INET) {
        continue;
      }
      auto* addr =
          reinterpret_cast<sockaddr_in*>(unicast->Address.lpSockaddr);
      char ip[INET_ADDRSTRLEN] = {};
      inet_ntop(AF_INET, &(addr->sin_addr), ip, INET_ADDRSTRLEN);
      std::string candidate_ip(ip);
      if (IsUsableIpv4(candidate_ip)) {
        candidate.ipv4 = candidate_ip;
        break;
      }
      if (fallback_ip.empty() && !candidate_ip.empty() &&
          !IsLoopbackIpv4(candidate_ip)) {
        fallback_ip = candidate_ip;
      }
    }
    if (candidate.ipv4.empty()) {
      candidate.ipv4 = fallback_ip;
    }
    out.push_back(std::move(candidate));
  }
  return out;
}

flutter::EncodableMap GetNetworkInfo() {
  const auto selection =
      SelectNetwork(CollectNetworkCandidates(), BestIpv4InterfaceIndex());
  if (!selection.found) {
    return MakeMap({
        {"ipAddress", flutter::EncodableValue()},
        {"networkType", flutter::EncodableValue(selection.type)},
        {"macAddress", flutter::EncodableValue()},
    });
  }
  return MakeMap({
      {"ipAddress", NullOrString(selection.ipv4)},
      {"networkType", flutter::EncodableValue(selection.type)},
      {"macAddress", NullOrString(selection.mac)},
  });
}

std::wstring WindowsVolumeRoot() {
  wchar_t windows_dir[MAX_PATH] = {};
  if (GetWindowsDirectoryW(windows_dir, MAX_PATH) > 0 &&
      windows_dir[0] != L'\0') {
    return std::wstring(1, windows_dir[0]) + L":\\";
  }
  return L"C:\\";
}

// Open \\.\X: for IOCTL_STORAGE_QUERY_PROPERTY (Raymond Chen / winioctl docs).
std::string ResolveStorageTypeForVolume(const std::wstring& root) {
  if (root.size() < 2 || root[1] != L':') {
    return {};
  }
  const std::wstring volume_path =
      std::wstring(L"\\\\.\\") + root.substr(0, 2);
  HANDLE handle =
      CreateFileW(volume_path.c_str(), 0,
                  FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0,
                  nullptr);
  if (handle == INVALID_HANDLE_VALUE) {
    return {};
  }

  STORAGE_PROPERTY_QUERY query = {};
  query.PropertyId = StorageDeviceSeekPenaltyProperty;
  query.QueryType = PropertyStandardQuery;
  DEVICE_SEEK_PENALTY_DESCRIPTOR result = {};
  DWORD bytes = 0;
  const BOOL ok =
      DeviceIoControl(handle, IOCTL_STORAGE_QUERY_PROPERTY, &query,
                      sizeof(query), &result, sizeof(result), &bytes, nullptr);
  CloseHandle(handle);
  return StorageTypeFromSeekPenalty(ok == TRUE, result.IncursSeekPenalty != 0);
}

flutter::EncodableMap GetStorageInfo() {
  const std::wstring root = WindowsVolumeRoot();

  ULARGE_INTEGER free_bytes = {};
  ULARGE_INTEGER total_bytes = {};
  if (!GetDiskFreeSpaceExW(root.c_str(), &free_bytes, &total_bytes, nullptr)) {
    return MakeMap({
        {"totalBytes", flutter::EncodableValue(static_cast<int64_t>(0))},
        {"freeBytes", flutter::EncodableValue(static_cast<int64_t>(0))},
        {"storageType", flutter::EncodableValue()},
    });
  }
  const std::string storage_type = ResolveStorageTypeForVolume(root);
  return MakeMap({
      {"totalBytes",
       flutter::EncodableValue(static_cast<int64_t>(total_bytes.QuadPart))},
      {"freeBytes",
       flutter::EncodableValue(static_cast<int64_t>(free_bytes.QuadPart))},
      {"storageType", NullOrString(storage_type)},
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
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "xue_hua_device_info",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<XueHuaDeviceInfoPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

XueHuaDeviceInfoPlugin::XueHuaDeviceInfoPlugin() {}

XueHuaDeviceInfoPlugin::~XueHuaDeviceInfoPlugin() {}

void XueHuaDeviceInfoPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = method_call.method_name();
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
