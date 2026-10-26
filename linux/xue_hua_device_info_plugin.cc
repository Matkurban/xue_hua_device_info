#include "include/xue_hua_device_info/xue_hua_device_info_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <net/if.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#include "device_info_helpers.h"

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

G_DEFINE_TYPE(XueHuaDeviceInfoPlugin, xue_hua_device_info_plugin, g_object_get_type())

static FlValue* NullableString(const std::string& value) {
  if (value.empty()) {
    return fl_value_new_null();
  }
  return fl_value_new_string(value.c_str());
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

static FlValue* BuildDeviceInfo() {
  std::string uuid = ResolveDeviceId();
  std::string manufacturer = ReadTrimmedFile("/sys/class/dmi/id/sys_vendor");
  std::string model = ReadTrimmedFile("/sys/class/dmi/id/product_name");
  std::string serial = ReadTrimmedFile("/sys/class/dmi/id/product_serial");
  char hostname[256] = {};
  std::string name;
  if (gethostname(hostname, sizeof(hostname)) == 0) {
    // POSIX: truncated names may omit the NUL terminator.
    hostname[sizeof(hostname) - 1] = '\0';
    name = hostname;
  }

  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "deviceId", NullableString(uuid));
  fl_value_set_string_take(map, "manufacturer", NullableString(manufacturer));
  fl_value_set_string_take(map, "model", NullableString(model));
  fl_value_set_string_take(map, "serial", NullableString(serial));
  fl_value_set_string_take(map, "name", NullableString(name));
  return fl_value_ref(map);
}

static FlValue* BuildBatteryInfo() {
  const BatteryReading battery = ReadBattery();
  g_autoptr(FlValue) map = fl_value_new_map();
  if (!battery.found) {
    fl_value_set_string_take(map, "level", fl_value_new_null());
    fl_value_set_string_take(map, "isCharging", fl_value_new_null());
    fl_value_set_string_take(map, "health", fl_value_new_null());
  } else {
    fl_value_set_string_take(map, "level", fl_value_new_float(battery.level));
    fl_value_set_string_take(map, "isCharging",
                             fl_value_new_bool(battery.is_charging));
    fl_value_set_string_take(map, "health", NullableString(battery.health));
  }
  return fl_value_ref(map);
}

static FlValue* BuildNetworkInfo() {
  const NetworkSelection net = SelectNetwork(
      EnumerateIpv4(),
      ParseDefaultRouteInterface(ReadWholeFile("/proc/net/route")));
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "ipAddress", NullableString(net.ipv4));
  fl_value_set_string_take(
      map, "networkType",
      fl_value_new_string(net.found ? net.type.c_str() : "none"));
  fl_value_set_string_take(map, "macAddress", NullableString(net.mac));
  return fl_value_ref(map);
}

static FlValue* BuildStorageInfo() {
  struct statvfs stat = {};
  int64_t total = 0;
  int64_t free_bytes = 0;
  if (statvfs("/", &stat) == 0) {
    total = static_cast<int64_t>(stat.f_blocks) *
            static_cast<int64_t>(stat.f_frsize);
    free_bytes = static_cast<int64_t>(stat.f_bavail) *
                 static_cast<int64_t>(stat.f_frsize);
  }
  // Kernel Documentation/block/queue-sysfs.rst: queue/rotational is 0 for
  // non-rotational (SSD) and 1 for rotational (HDD). Mapped to "ssd"/"hdd".
  const std::string storage_type = ResolveStorageType("/");
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "totalBytes", fl_value_new_int(total));
  fl_value_set_string_take(map, "freeBytes", fl_value_new_int(free_bytes));
  fl_value_set_string_take(map, "storageType", NullableString(storage_type));
  return fl_value_ref(map);
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

static FlValue* BuildDisplayInfo() {
  int width = 0;
  int height = 0;
  double scale = 1.0;
  double refresh = 0;

  GdkMonitor* monitor = PickMonitor(gdk_display_get_default());
  if (monitor != nullptr) {
    GdkRectangle geometry = {};
    gdk_monitor_get_geometry(monitor, &geometry);
    const int factor = gdk_monitor_get_scale_factor(monitor);
    scale = factor > 0 ? static_cast<double>(factor) : 1.0;
    width = static_cast<int>(geometry.width * scale);
    height = static_cast<int>(geometry.height * scale);
    // GDK reports the refresh rate in millihertz (0 when unknown).
    const int refresh_mhz = gdk_monitor_get_refresh_rate(monitor);
    if (refresh_mhz > 0) {
      refresh = refresh_mhz / 1000.0;
    }
  }

  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "width", fl_value_new_int(width));
  fl_value_set_string_take(map, "height", fl_value_new_int(height));
  fl_value_set_string_take(map, "scaleFactor", fl_value_new_float(scale));
  if (refresh > 0) {
    fl_value_set_string_take(map, "refreshRate", fl_value_new_float(refresh));
  } else {
    fl_value_set_string_take(map, "refreshRate", fl_value_new_null());
  }
  return fl_value_ref(map);
}

static void xue_hua_device_info_plugin_handle_method_call(
    XueHuaDeviceInfoPlugin* /*self*/,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  g_autoptr(FlValue) result = nullptr;
  if (strcmp(method, "getDeviceInfo") == 0) {
    result = BuildDeviceInfo();
  } else if (strcmp(method, "getBatteryInfo") == 0) {
    result = BuildBatteryInfo();
  } else if (strcmp(method, "getNetworkInfo") == 0) {
    result = BuildNetworkInfo();
  } else if (strcmp(method, "getStorageInfo") == 0) {
    result = BuildStorageInfo();
  } else if (strcmp(method, "getDisplayInfo") == 0) {
    result = BuildDisplayInfo();
  }

  if (result != nullptr) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void xue_hua_device_info_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(xue_hua_device_info_plugin_parent_class)->dispose(object);
}

static void xue_hua_device_info_plugin_class_init(XueHuaDeviceInfoPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_device_info_plugin_dispose;
}

static void xue_hua_device_info_plugin_init(XueHuaDeviceInfoPlugin* /*self*/) {}

static void method_call_cb(FlMethodChannel* /*channel*/, FlMethodCall* method_call,
                           gpointer user_data) {
  XueHuaDeviceInfoPlugin* plugin = XUE_HUA_DEVICE_INFO_PLUGIN(user_data);
  xue_hua_device_info_plugin_handle_method_call(plugin, method_call);
}

void xue_hua_device_info_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  XueHuaDeviceInfoPlugin* plugin = XUE_HUA_DEVICE_INFO_PLUGIN(
      g_object_new(xue_hua_device_info_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "xue_hua_device_info",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
