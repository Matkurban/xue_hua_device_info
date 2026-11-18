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
#include "messages.g.h"

#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <string>
#include <vector>

namespace xue_hua_device_info {

namespace {

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

std::string ResolveWindowsArchitecture() {
  SYSTEM_INFO sys_info = {};
  GetNativeSystemInfo(&sys_info);
  switch (sys_info.wProcessorArchitecture) {
    case PROCESSOR_ARCHITECTURE_AMD64:
      return "x86_64";
    case PROCESSOR_ARCHITECTURE_ARM64:
      return "arm64";
    case PROCESSOR_ARCHITECTURE_INTEL:
      return "x86";
    case PROCESSOR_ARCHITECTURE_ARM:
      return "arm";
    default:
      return "unknown";
  }
}

std::string ResolveWindowsOsVersion() {
  const auto product_name = WideToUtf8(ReadRegistryString(
      HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
      L"ProductName"));
  const auto build_number = WideToUtf8(ReadRegistryString(
      HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
      L"CurrentBuildNumber"));
  if (!product_name.empty() && !build_number.empty()) {
    return product_name + " (Build " + build_number + ")";
  }
  return !product_name.empty() ? product_name : build_number;
}

unsigned long BestIpv4InterfaceIndex() {
  sockaddr_in dest = {};
  dest.sin_family = AF_INET;
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

std::wstring WindowsVolumeRoot() {
  wchar_t windows_dir[MAX_PATH] = {};
  if (GetWindowsDirectoryW(windows_dir, MAX_PATH) > 0 &&
      windows_dir[0] != L'\0') {
    return std::wstring(1, windows_dir[0]) + L":\\";
  }
  return L"C:\\";
}

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

}  // namespace

// static
void XueHuaDeviceInfoPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<XueHuaDeviceInfoPlugin>();
  XueHuaDeviceInfoHostApi::SetUp(registrar->messenger(), plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

XueHuaDeviceInfoPlugin::XueHuaDeviceInfoPlugin() = default;

XueHuaDeviceInfoPlugin::~XueHuaDeviceInfoPlugin() = default;

ErrorOr<PigeonDeviceInfo> XueHuaDeviceInfoPlugin::GetDeviceInfo() {
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

  const std::string os_ver = ResolveWindowsOsVersion();
  const std::string arch = ResolveWindowsArchitecture();

  PigeonDeviceInfo info;
  if (!uuid.empty()) info.set_device_id(uuid);
  if (!manufacturer.empty()) info.set_manufacturer(manufacturer);
  if (!model.empty()) info.set_model(model);
  if (!serial.empty()) info.set_serial(serial);
  if (!name.empty()) info.set_name(name);
  info.set_operating_system("windows");
  if (!os_ver.empty()) info.set_os_version(os_ver);
  if (!arch.empty()) info.set_architecture(arch);
  return info;
}

ErrorOr<PigeonBatteryInfo> XueHuaDeviceInfoPlugin::GetBatteryInfo() {
  SYSTEM_POWER_STATUS status = {};
  if (!GetSystemPowerStatus(&status) || status.BatteryFlag == 128) {
    return PigeonBatteryInfo(PigeonBatteryChargingState::kUnknown,
                             PigeonBatteryHealthStatus::kUnknown, false);
  }

  const bool is_charging = (status.BatteryFlag & 8) != 0;
  PigeonBatteryChargingState charging_state =
      is_charging ? PigeonBatteryChargingState::kCharging
                  : PigeonBatteryChargingState::kDischarging;
  if (!is_charging && status.BatteryLifePercent == 100 &&
      status.ACLineStatus == 1) {
    charging_state = PigeonBatteryChargingState::kFull;
  }

  PigeonBatteryInfo info(charging_state, PigeonBatteryHealthStatus::kUnknown,
                         true);
  if (status.BatteryLifePercent != 255) {
    info.set_level(static_cast<double>(status.BatteryLifePercent));
  }
  info.set_is_charging(is_charging);
  return info;
}

ErrorOr<PigeonNetworkInfo> XueHuaDeviceInfoPlugin::GetNetworkInfo() {
  const auto selection =
      SelectNetwork(CollectNetworkCandidates(), BestIpv4InterfaceIndex());
  if (!selection.found) {
    const auto conn_type = selection.type == "none"
                               ? PigeonNetworkConnectionType::kNone
                               : PigeonNetworkConnectionType::kUnknown;
    return PigeonNetworkInfo(conn_type, selection.type);
  }

  PigeonNetworkConnectionType conn_type = PigeonNetworkConnectionType::kUnknown;
  if (selection.type == "wifi") {
    conn_type = PigeonNetworkConnectionType::kWifi;
  } else if (selection.type == "ethernet") {
    conn_type = PigeonNetworkConnectionType::kEthernet;
  } else if (selection.type == "cellular") {
    conn_type = PigeonNetworkConnectionType::kCellular;
  }

  PigeonNetworkInfo info(conn_type, selection.type);
  if (!selection.ipv4.empty()) info.set_ip_address(selection.ipv4);
  if (!selection.mac.empty()) info.set_mac_address(selection.mac);
  if (!selection.interface_name.empty()) {
    info.set_interface_name(selection.interface_name);
  }
  return info;
}

ErrorOr<PigeonStorageInfo> XueHuaDeviceInfoPlugin::GetStorageInfo() {
  const std::wstring root = WindowsVolumeRoot();

  ULARGE_INTEGER free_bytes = {};
  ULARGE_INTEGER total_bytes = {};
  if (!GetDiskFreeSpaceExW(root.c_str(), &free_bytes, &total_bytes, nullptr)) {
    return PigeonStorageInfo(0, 0, PigeonStorageMediumType::kUnknown);
  }
  const std::string storage_type = ResolveStorageTypeForVolume(root);
  PigeonStorageMediumType medium_type = PigeonStorageMediumType::kUnknown;
  if (storage_type == "ssd") {
    medium_type = PigeonStorageMediumType::kSsd;
  } else if (storage_type == "hdd") {
    medium_type = PigeonStorageMediumType::kHdd;
  }

  PigeonStorageInfo info(static_cast<int64_t>(total_bytes.QuadPart),
                         static_cast<int64_t>(free_bytes.QuadPart),
                         medium_type);
  if (!storage_type.empty()) {
    info.set_storage_type(storage_type);
  }
  return info;
}

ErrorOr<PigeonDisplayInfo> XueHuaDeviceInfoPlugin::GetDisplayInfo() {
  const int64_t width = static_cast<int64_t>(GetSystemMetrics(SM_CXSCREEN));
  const int64_t height = static_cast<int64_t>(GetSystemMetrics(SM_CYSCREEN));
  double scale = 1.0;
  HDC hdc = GetDC(nullptr);
  if (hdc != nullptr) {
    const int dpi = GetDeviceCaps(hdc, LOGPIXELSX);
    scale = static_cast<double>(dpi) / 96.0;
    ReleaseDC(nullptr, hdc);
  }

  PigeonDisplayInfo info(width, height, scale);
  DEVMODEW mode = {};
  mode.dmSize = sizeof(mode);
  if (EnumDisplaySettingsW(nullptr, ENUM_CURRENT_SETTINGS, &mode) &&
      mode.dmDisplayFrequency > 1) {
    info.set_refresh_rate(static_cast<double>(mode.dmDisplayFrequency));
  }
  return info;
}

}  // namespace xue_hua_device_info
