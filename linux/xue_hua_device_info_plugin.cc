#include "include/xue_hua_device_info/xue_hua_device_info_plugin.h"

#include <arpa/inet.h>
#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <sys/utsname.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "device_info_helpers.h"
#include "messages.g.h"

using xue_hua_device_info::BatteryReading;
using xue_hua_device_info::NetworkSelection;
using xue_hua_device_info::ParseDefaultRouteInterface;
using xue_hua_device_info::ReadBattery;
using xue_hua_device_info::ReadTrimmedFile;
using xue_hua_device_info::ResolveDeviceId;
using xue_hua_device_info::ResolveStorageType;
using xue_hua_device_info::SelectNetwork;

#define XUE_HUA_DEVICE_INFO_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_device_info_plugin_get_type(), \
                              XueHuaDeviceInfoPlugin))

struct _XueHuaDeviceInfoPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(XueHuaDeviceInfoPlugin, xue_hua_device_info_plugin,
              g_object_get_type())

static const gchar* NullOrCString(const std::string& value) {
  return value.empty() ? nullptr : value.c_str();
}

static std::vector<xue_hua_device_info::NetworkCandidate> EnumerateIpv4() {
  std::vector<xue_hua_device_info::NetworkCandidate> result;
  struct ifaddrs* ifaddr = nullptr;
  if (getifaddrs(&ifaddr) != 0) {
    return result;
  }
  for (struct ifaddrs* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
    if (ifa->ifa_name == nullptr || ifa->ifa_addr == nullptr ||
        ifa->ifa_addr->sa_family != AF_INET) {
      continue;
    }
    char host[INET_ADDRSTRLEN] = {};
    auto* addr = reinterpret_cast<sockaddr_in*>(ifa->ifa_addr);
    if (inet_ntop(AF_INET, &addr->sin_addr, host, INET_ADDRSTRLEN) == nullptr) {
      continue;
    }
    xue_hua_device_info::NetworkCandidate candidate;
    candidate.name = ifa->ifa_name;
    candidate.ipv4 = host;
    candidate.is_up = (ifa->ifa_flags & IFF_UP) != 0;
    candidate.is_loopback = (ifa->ifa_flags & IFF_LOOPBACK) != 0;
    result.push_back(candidate);
  }
  freeifaddrs(ifaddr);
  return result;
}

static std::string ReadWholeFile(const char* path) {
  std::ifstream input(path);
  std::stringstream buffer;
  buffer << input.rdbuf();
  return buffer.str();
}

static XueHuaDeviceInfoXueHuaDeviceInfoHostApiGetDeviceInfoResponse*
HandleGetDeviceInfo(gpointer /*user_data*/) {
  const std::string uuid = ResolveDeviceId();
  const std::string manufacturer =
      ReadTrimmedFile("/sys/class/dmi/id/sys_vendor");
  const std::string model = ReadTrimmedFile("/sys/class/dmi/id/product_name");
  const std::string serial =
      ReadTrimmedFile("/sys/class/dmi/id/product_serial");
  char hostname[256] = {};
  std::string name;
  if (gethostname(hostname, sizeof(hostname)) == 0) {
    hostname[sizeof(hostname) - 1] = '\0';
    name = hostname;
  }

  struct utsname uts = {};
  std::string os_version;
  std::string arch;
  if (uname(&uts) == 0) {
    os_version = uts.release;
    arch = uts.machine;
  }

  g_autoptr(XueHuaDeviceInfoPigeonDeviceInfo) info =
      xue_hua_device_info_pigeon_device_info_new(
          NullOrCString(uuid), NullOrCString(manufacturer),
          NullOrCString(model), NullOrCString(serial), NullOrCString(name),
          "linux", NullOrCString(os_version), NullOrCString(arch));
  return xue_hua_device_info_xue_hua_device_info_host_api_get_device_info_response_new(
      info);
}

static XueHuaDeviceInfoXueHuaDeviceInfoHostApiGetBatteryInfoResponse*
HandleGetBatteryInfo(gpointer /*user_data*/) {
  const BatteryReading battery = ReadBattery();
  if (!battery.found) {
    g_autoptr(XueHuaDeviceInfoPigeonBatteryInfo) info =
        xue_hua_device_info_pigeon_battery_info_new(
            nullptr, nullptr,
            XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_CHARGING_STATE_UNKNOWN,
            XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_HEALTH_STATUS_UNKNOWN, nullptr,
            FALSE);
    return xue_hua_device_info_xue_hua_device_info_host_api_get_battery_info_response_new(
        info);
  }

  const gdouble level = battery.level;
  const gboolean is_charging = battery.is_charging ? TRUE : FALSE;
  const XueHuaDeviceInfoPigeonBatteryChargingState charging_state =
      battery.is_charging
          ? XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_CHARGING_STATE_CHARGING
          : XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_CHARGING_STATE_DISCHARGING;

  XueHuaDeviceInfoPigeonBatteryHealthStatus health_status =
      XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_HEALTH_STATUS_UNKNOWN;
  if (battery.health == "Good") {
    health_status = XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_HEALTH_STATUS_GOOD;
  } else if (battery.health == "Overheat") {
    health_status = XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_HEALTH_STATUS_OVERHEAT;
  } else if (battery.health == "Dead") {
    health_status = XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_HEALTH_STATUS_DEAD;
  } else if (battery.health == "Over voltage") {
    health_status =
        XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_HEALTH_STATUS_OVER_VOLTAGE;
  } else if (battery.health == "Cold") {
    health_status = XUE_HUA_DEVICE_INFO_PIGEON_BATTERY_HEALTH_STATUS_COLD;
  }

  g_autoptr(XueHuaDeviceInfoPigeonBatteryInfo) info =
      xue_hua_device_info_pigeon_battery_info_new(
          &level, &is_charging, charging_state, health_status,
          NullOrCString(battery.health), TRUE);
  return xue_hua_device_info_xue_hua_device_info_host_api_get_battery_info_response_new(
      info);
}

static XueHuaDeviceInfoXueHuaDeviceInfoHostApiGetNetworkInfoResponse*
HandleGetNetworkInfo(gpointer /*user_data*/) {
  const NetworkSelection net = SelectNetwork(
      EnumerateIpv4(),
      ParseDefaultRouteInterface(ReadWholeFile("/proc/net/route")));
  const std::string net_type = net.found ? net.type : "none";
  XueHuaDeviceInfoPigeonNetworkConnectionType conn_type =
      XUE_HUA_DEVICE_INFO_PIGEON_NETWORK_CONNECTION_TYPE_UNKNOWN;
  if (net_type == "none") {
    conn_type = XUE_HUA_DEVICE_INFO_PIGEON_NETWORK_CONNECTION_TYPE_NONE;
  } else if (net_type == "wifi") {
    conn_type = XUE_HUA_DEVICE_INFO_PIGEON_NETWORK_CONNECTION_TYPE_WIFI;
  } else if (net_type == "ethernet") {
    conn_type = XUE_HUA_DEVICE_INFO_PIGEON_NETWORK_CONNECTION_TYPE_ETHERNET;
  } else if (net_type == "cellular") {
    conn_type = XUE_HUA_DEVICE_INFO_PIGEON_NETWORK_CONNECTION_TYPE_CELLULAR;
  }

  g_autoptr(XueHuaDeviceInfoPigeonNetworkInfo) info =
      xue_hua_device_info_pigeon_network_info_new(
          NullOrCString(net.ipv4), conn_type, net_type.c_str(),
          NullOrCString(net.mac), NullOrCString(net.name));
  return xue_hua_device_info_xue_hua_device_info_host_api_get_network_info_response_new(
      info);
}

static XueHuaDeviceInfoXueHuaDeviceInfoHostApiGetStorageInfoResponse*
HandleGetStorageInfo(gpointer /*user_data*/) {
  struct statvfs stat = {};
  int64_t total = 0;
  int64_t free_bytes = 0;
  if (statvfs("/", &stat) == 0) {
    total = static_cast<int64_t>(stat.f_blocks) *
            static_cast<int64_t>(stat.f_frsize);
    free_bytes = static_cast<int64_t>(stat.f_bavail) *
                 static_cast<int64_t>(stat.f_frsize);
  }
  const std::string storage_type = ResolveStorageType("/");
  XueHuaDeviceInfoPigeonStorageMediumType medium_type =
      XUE_HUA_DEVICE_INFO_PIGEON_STORAGE_MEDIUM_TYPE_UNKNOWN;
  if (storage_type == "ssd") {
    medium_type = XUE_HUA_DEVICE_INFO_PIGEON_STORAGE_MEDIUM_TYPE_SSD;
  } else if (storage_type == "hdd") {
    medium_type = XUE_HUA_DEVICE_INFO_PIGEON_STORAGE_MEDIUM_TYPE_HDD;
  }

  g_autoptr(XueHuaDeviceInfoPigeonStorageInfo) info =
      xue_hua_device_info_pigeon_storage_info_new(
          total, free_bytes, medium_type, NullOrCString(storage_type));
  return xue_hua_device_info_xue_hua_device_info_host_api_get_storage_info_response_new(
      info);
}

static GdkMonitor* PickMonitor(GdkDisplay* display) {
  if (display == nullptr) {
    return nullptr;
  }
  GdkMonitor* monitor = gdk_display_get_primary_monitor(display);
  if (monitor == nullptr && gdk_display_get_n_monitors(display) > 0) {
    monitor = gdk_display_get_monitor(display, 0);
  }
  return monitor;
}

static XueHuaDeviceInfoXueHuaDeviceInfoHostApiGetDisplayInfoResponse*
HandleGetDisplayInfo(gpointer /*user_data*/) {
  gint64 width = 0;
  gint64 height = 0;
  gdouble scale = 1.0;
  gdouble refresh = 0.0;

  GdkMonitor* monitor = PickMonitor(gdk_display_get_default());
  if (monitor != nullptr) {
    GdkRectangle geometry = {};
    gdk_monitor_get_geometry(monitor, &geometry);
    const int factor = gdk_monitor_get_scale_factor(monitor);
    scale = factor > 0 ? static_cast<gdouble>(factor) : 1.0;
    width = static_cast<gint64>(geometry.width * scale);
    height = static_cast<gint64>(geometry.height * scale);
    const int refresh_mhz = gdk_monitor_get_refresh_rate(monitor);
    if (refresh_mhz > 0) {
      refresh = refresh_mhz / 1000.0;
    }
  }

  const gdouble* refresh_ptr = refresh > 0.0 ? &refresh : nullptr;
  g_autoptr(XueHuaDeviceInfoPigeonDisplayInfo) info =
      xue_hua_device_info_pigeon_display_info_new(width, height, scale,
                                                  refresh_ptr);
  return xue_hua_device_info_xue_hua_device_info_host_api_get_display_info_response_new(
      info);
}

static void xue_hua_device_info_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(xue_hua_device_info_plugin_parent_class)->dispose(object);
}

static void xue_hua_device_info_plugin_class_init(
    XueHuaDeviceInfoPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_device_info_plugin_dispose;
}

static void xue_hua_device_info_plugin_init(XueHuaDeviceInfoPlugin* /*self*/) {}

void xue_hua_device_info_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  XueHuaDeviceInfoPlugin* plugin = XUE_HUA_DEVICE_INFO_PLUGIN(
      g_object_new(xue_hua_device_info_plugin_get_type(), nullptr));

  static const XueHuaDeviceInfoXueHuaDeviceInfoHostApiVTable vtable = {
      .get_device_info = HandleGetDeviceInfo,
      .get_battery_info = HandleGetBatteryInfo,
      .get_network_info = HandleGetNetworkInfo,
      .get_storage_info = HandleGetStorageInfo,
      .get_display_info = HandleGetDisplayInfo,
  };

  xue_hua_device_info_xue_hua_device_info_host_api_set_method_handlers(
      fl_plugin_registrar_get_messenger(registrar), nullptr, &vtable,
      g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
