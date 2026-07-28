#include "include/xue_hua_device_info/xue_hua_device_info_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>

#define XUE_HUA_DEVICE_INFO_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_device_info_plugin_get_type(), \
                              XueHuaDeviceInfoPlugin))

struct _XueHuaDeviceInfoPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(XueHuaDeviceInfoPlugin, xue_hua_device_info_plugin, g_object_get_type())

static std::string ReadTrimmedFile(const char* path) {
  std::ifstream input(path);
  if (!input.is_open()) {
    return {};
  }
  std::stringstream buffer;
  buffer << input.rdbuf();
  std::string value = buffer.str();
  while (!value.empty() &&
         (value.back() == '\n' || value.back() == '\r' || value.back() == ' ')) {
    value.pop_back();
  }
  if (value == "None" || value == "To be filled by O.E.M.") {
    return {};
  }
  return value;
}

static FlValue* NullableString(const std::string& value) {
  if (value.empty()) {
    return fl_value_new_null();
  }
  return fl_value_new_string(value.c_str());
}

static std::string LocalIpv4() {
  struct ifaddrs* ifaddr = nullptr;
  if (getifaddrs(&ifaddr) != 0) {
    return {};
  }
  std::string result;
  for (struct ifaddrs* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
    if (ifa->ifa_addr == nullptr || ifa->ifa_addr->sa_family != AF_INET) {
      continue;
    }
    if (strncmp(ifa->ifa_name, "lo", 2) == 0) {
      continue;
    }
    char host[INET_ADDRSTRLEN] = {};
    auto* addr = reinterpret_cast<sockaddr_in*>(ifa->ifa_addr);
    inet_ntop(AF_INET, &addr->sin_addr, host, INET_ADDRSTRLEN);
    std::string candidate(host);
    if (!candidate.empty() && candidate.rfind("127.", 0) != 0) {
      result = candidate;
      if (strncmp(ifa->ifa_name, "eth", 3) == 0 ||
          strncmp(ifa->ifa_name, "en", 2) == 0 ||
          strncmp(ifa->ifa_name, "wl", 2) == 0) {
        break;
      }
    }
  }
  freeifaddrs(ifaddr);
  return result;
}

static std::string PrimaryMac() {
  struct ifaddrs* ifaddr = nullptr;
  if (getifaddrs(&ifaddr) != 0) {
    return {};
  }
  std::string result;
  for (struct ifaddrs* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
    if (ifa->ifa_name == nullptr) {
      continue;
    }
    if (strncmp(ifa->ifa_name, "lo", 2) == 0) {
      continue;
    }
    std::string path = std::string("/sys/class/net/") + ifa->ifa_name + "/address";
    std::string mac = ReadTrimmedFile(path.c_str());
    if (!mac.empty() && mac != "00:00:00:00:00:00") {
      result = mac;
      if (strncmp(ifa->ifa_name, "eth", 3) == 0 ||
          strncmp(ifa->ifa_name, "en", 2) == 0 ||
          strncmp(ifa->ifa_name, "wl", 2) == 0) {
        break;
      }
    }
  }
  freeifaddrs(ifaddr);
  return result;
}

static std::string NetworkType() {
  std::string ip = LocalIpv4();
  if (ip.empty()) {
    return "none";
  }
  struct ifaddrs* ifaddr = nullptr;
  if (getifaddrs(&ifaddr) != 0) {
    return "unknown";
  }
  std::string type = "unknown";
  for (struct ifaddrs* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
    if (ifa->ifa_name == nullptr || ifa->ifa_addr == nullptr ||
        ifa->ifa_addr->sa_family != AF_INET) {
      continue;
    }
    if (strncmp(ifa->ifa_name, "wl", 2) == 0 ||
        strncmp(ifa->ifa_name, "wlan", 4) == 0) {
      type = "wifi";
      break;
    }
    if (strncmp(ifa->ifa_name, "eth", 3) == 0 ||
        strncmp(ifa->ifa_name, "en", 2) == 0) {
      type = "ethernet";
    }
  }
  freeifaddrs(ifaddr);
  return type;
}

static FlValue* BuildDeviceInfo() {
  std::string uuid = ReadTrimmedFile("/sys/class/dmi/id/product_uuid");
  if (uuid.empty()) {
    uuid = ReadTrimmedFile("/etc/machine-id");
  }
  std::string manufacturer = ReadTrimmedFile("/sys/class/dmi/id/sys_vendor");
  std::string model = ReadTrimmedFile("/sys/class/dmi/id/product_name");
  std::string serial = ReadTrimmedFile("/sys/class/dmi/id/product_serial");
  char hostname[256] = {};
  std::string name;
  if (gethostname(hostname, sizeof(hostname)) == 0) {
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
  std::string capacity = ReadTrimmedFile("/sys/class/power_supply/BAT0/capacity");
  if (capacity.empty()) {
    capacity = ReadTrimmedFile("/sys/class/power_supply/BAT1/capacity");
  }
  std::string status = ReadTrimmedFile("/sys/class/power_supply/BAT0/status");
  if (status.empty()) {
    status = ReadTrimmedFile("/sys/class/power_supply/BAT1/status");
  }

  g_autoptr(FlValue) map = fl_value_new_map();
  char* end = nullptr;
  const double parsed = capacity.empty() ? -1.0 : strtod(capacity.c_str(), &end);
  const bool level_ok =
      !capacity.empty() && end != capacity.c_str() && parsed >= 0.0 && parsed <= 100.0;
  if (!level_ok) {
    fl_value_set_string_take(map, "level", fl_value_new_null());
    fl_value_set_string_take(map, "isCharging", fl_value_new_null());
    fl_value_set_string_take(map, "health", fl_value_new_null());
  } else {
    fl_value_set_string_take(map, "level", fl_value_new_float(parsed));
    bool charging = status == "Charging" || status == "Full";
    fl_value_set_string_take(map, "isCharging", fl_value_new_bool(charging));
    fl_value_set_string_take(map, "health", fl_value_new_null());
  }
  return fl_value_ref(map);
}

static FlValue* BuildNetworkInfo() {
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "ipAddress", NullableString(LocalIpv4()));
  fl_value_set_string_take(map, "networkType",
                           fl_value_new_string(NetworkType().c_str()));
  fl_value_set_string_take(map, "macAddress", NullableString(PrimaryMac()));
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
  g_autoptr(FlValue) map = fl_value_new_map();
  fl_value_set_string_take(map, "totalBytes", fl_value_new_int(total));
  fl_value_set_string_take(map, "freeBytes", fl_value_new_int(free_bytes));
  fl_value_set_string_take(map, "storageType", fl_value_new_null());
  return fl_value_ref(map);
}

static FlValue* BuildDisplayInfo() {
  int width = 0;
  int height = 0;
  double refresh = 0;
  FILE* pipe = popen("xrandr --current 2>/dev/null", "r");
  if (pipe != nullptr) {
    char line[512];
    while (fgets(line, sizeof(line), pipe) != nullptr) {
      // Look for: "   1920x1080     60.00*+"
      int w = 0;
      int h = 0;
      double rate = 0;
      char mark = 0;
      if (sscanf(line, " %dx%d %lf%c", &w, &h, &rate, &mark) >= 3) {
        if (strchr(line, '*') != nullptr) {
          width = w;
          height = h;
          refresh = rate;
          break;
        }
      }
    }
    pclose(pipe);
  }

  // Fallback via GDK if xrandr unavailable.
  if (width == 0 || height == 0) {
    GdkDisplay* display = gdk_display_get_default();
    if (display != nullptr) {
      GdkMonitor* monitor = gdk_display_get_primary_monitor(display);
      if (monitor == nullptr && gdk_display_get_n_monitors(display) > 0) {
        monitor = gdk_display_get_monitor(display, 0);
      }
      if (monitor != nullptr) {
        GdkRectangle geometry = {};
        gdk_monitor_get_geometry(monitor, &geometry);
        width = geometry.width * gdk_monitor_get_scale_factor(monitor);
        height = geometry.height * gdk_monitor_get_scale_factor(monitor);
      }
    }
  }

  double scale = 1.0;
  GdkDisplay* display = gdk_display_get_default();
  if (display != nullptr) {
    GdkMonitor* monitor = gdk_display_get_primary_monitor(display);
    if (monitor == nullptr && gdk_display_get_n_monitors(display) > 0) {
      monitor = gdk_display_get_monitor(display, 0);
    }
    if (monitor != nullptr) {
      scale = static_cast<double>(gdk_monitor_get_scale_factor(monitor));
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
    XueHuaDeviceInfoPlugin* self,
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

static void xue_hua_device_info_plugin_init(XueHuaDeviceInfoPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
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
