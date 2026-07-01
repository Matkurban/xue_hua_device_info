//! iOS device info via objc2.

use crate::models::*;
use block2::RcBlock;
use dispatch2::{DispatchQueue, DispatchQueueAttr};
use network_framework_sys::{
    dispatch_queue_t, nw_interface_type_cellular, nw_interface_type_wifi, nw_interface_type_wired,
    nw_path_get_status, nw_path_monitor_cancel, nw_path_monitor_create, nw_path_monitor_set_queue,
    nw_path_monitor_start, nw_path_monitor_t, nw_path_status_satisfied, nw_path_status_unsatisfied,
    nw_path_t, nw_path_uses_interface_type, nw_release,
};
use objc2::MainThreadMarker;
use objc2_foundation::{NSArray, NSNumber, NSString, NSURL, NSUUID};
use objc2_ui_kit::{UIDevice, UIDeviceBatteryState, UIScreen};
use security_framework::passwords::{
    delete_generic_password, get_generic_password, set_generic_password,
};
use std::ffi::CStr;
use std::sync::{Mutex, OnceLock};

const KEYCHAIN_SERVICE: &str = "com.xuehua.deviceinfo";
const KEYCHAIN_ACCOUNT: &str = "unique_id";

unsafe extern "C" {
    fn nw_path_monitor_set_update_handler(
        monitor: nw_path_monitor_t,
        update_handler: *const block2::Block<dyn Fn(nw_path_t)>,
    );
}

fn main_thread_marker() -> MainThreadMarker {
    // Flutter plugin calls run on the main thread.
    unsafe { MainThreadMarker::new_unchecked() }
}

pub fn get_device_info() -> crate::Result<DeviceInfoResponse> {
    let mtm = main_thread_marker();
    let device = UIDevice::currentDevice(mtm);
    let uuid = device
        .identifierForVendor()
        .map(|id| id.UUIDString().to_string());

    let model = get_machine_model().unwrap_or_else(|| device.model().to_string());
    let device_name = get_device_name(&device);
    let serial = get_persistent_device_id();

    Ok(DeviceInfoResponse {
        uuid,
        manufacturer: Some("Apple Inc.".to_string()),
        model: Some(model),
        serial: Some(serial),
        android_id: None,
        device_name: Some(device_name),
    })
}

pub fn get_battery_info() -> crate::Result<BatteryInfo> {
    let mtm = main_thread_marker();
    let device = UIDevice::currentDevice(mtm);
    device.setBatteryMonitoringEnabled(true);

    let level_raw = device.batteryLevel();
    let level = if level_raw >= 0.0 {
        Some(level_raw * 100.0)
    } else {
        None
    };

    let state = device.batteryState();
    let is_charging =
        state == UIDeviceBatteryState::Charging || state == UIDeviceBatteryState::Full;
    let health = match state {
        UIDeviceBatteryState::Unknown => "Unknown",
        UIDeviceBatteryState::Unplugged => "Good",
        UIDeviceBatteryState::Charging => "Good (Charging)",
        UIDeviceBatteryState::Full => "Good (Full)",
        _ => "Unknown",
    };

    Ok(BatteryInfo {
        level,
        is_charging: Some(is_charging),
        health: Some(health.to_string()),
    })
}

pub fn get_network_info() -> crate::Result<NetworkInfo> {
    let ip_address = get_ip_address();
    let network_type = detect_network_type();

    Ok(NetworkInfo {
        ip_address,
        network_type: Some(network_type),
        mac_address: Some("unavailable".to_string()),
    })
}

pub fn get_storage_info() -> crate::Result<StorageInfo> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/var/mobile".to_string());
    let path = NSString::from_str(&home);
    let url = NSURL::fileURLWithPath(&path);

    let total_key = NSString::from_str("NSURLVolumeTotalCapacityKey");
    let free_key = NSString::from_str("NSURLVolumeAvailableCapacityKey");
    let keys = NSArray::from_slice(&[&*total_key, &*free_key]);

    match url.resourceValuesForKeys_error(&keys) {
        Ok(dict) => {
            let total = dict
                .objectForKey(&total_key)
                .and_then(|n| n.downcast::<NSNumber>().ok())
                .map(|n| n.longLongValue() as u64)
                .unwrap_or(0);
            let free = dict
                .objectForKey(&free_key)
                .and_then(|n| n.downcast::<NSNumber>().ok())
                .map(|n| n.longLongValue() as u64)
                .unwrap_or(0);
            Ok(StorageInfo {
                total_space: total,
                free_space: free,
                storage_type: Some("internal".to_string()),
            })
        }
        Err(_) => Ok(StorageInfo {
            total_space: 0,
            free_space: 0,
            storage_type: Some("internal".to_string()),
        }),
    }
}

pub fn get_display_info() -> crate::Result<DisplayInfo> {
    let mtm = main_thread_marker();
    let screen = UIScreen::mainScreen(mtm);
    let bounds = screen.bounds();
    let scale = screen.scale() as f64;
    let refresh = screen.maximumFramesPerSecond() as f64;

    Ok(DisplayInfo {
        width: (bounds.size.width * scale) as u32,
        height: (bounds.size.height * scale) as u32,
        scale_factor: scale,
        refresh_rate: Some(refresh),
    })
}

fn get_machine_model() -> Option<String> {
    unsafe {
        let mut system_info: libc::utsname = std::mem::zeroed();
        if libc::uname(&mut system_info) != 0 {
            return None;
        }
        CStr::from_ptr(system_info.machine.as_ptr())
            .to_str()
            .ok()
            .map(|s| s.to_string())
    }
}

fn get_device_name(device: &UIDevice) -> String {
    let name = device.name().to_string();
    if name != "iPhone" && name != "iPad" && name != "iPod touch" {
        return name;
    }

    let host = objc2_foundation::NSProcessInfo::processInfo()
        .hostName()
        .to_string();
    if !host.is_empty() && host != "localhost" {
        let cleaned = host.replace(".local", "").replace('-', " ");
        return cleaned
            .split_whitespace()
            .map(capitalize_word)
            .collect::<Vec<_>>()
            .join(" ")
            .replace("Iphone", "iPhone")
            .replace("Ipad", "iPad")
            .replace("Ipod", "iPod");
    }

    name
}

fn capitalize_word(word: &str) -> String {
    let mut chars = word.chars();
    match chars.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

fn get_persistent_device_id() -> String {
    if let Ok(data) = get_generic_password(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT) {
        if let Ok(id) = String::from_utf8(data) {
            if !id.is_empty() {
                return id;
            }
        }
    }

    let new_id = NSUUID::UUID().UUIDString().to_string();
    let _ = delete_generic_password(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT);
    let _ = set_generic_password(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT, new_id.as_bytes());
    new_id
}

fn detect_network_type() -> String {
    static STORAGE: OnceLock<Mutex<Option<String>>> = OnceLock::new();
    let storage = STORAGE.get_or_init(|| Mutex::new(None));

    if let Ok(mut guard) = storage.lock() {
        *guard = None;
    }

    unsafe {
        let monitor = nw_path_monitor_create();
        if monitor.is_null() {
            return "unknown".to_string();
        }

        let storage_for_block = storage as *const Mutex<Option<String>>;

        let block = RcBlock::new(move |path: *mut libc::c_void| {
            let path = path as nw_path_t;
            if path.is_null() {
                return;
            }
            let status = nw_path_get_status(path);
            let network_type = if status == nw_path_status_satisfied {
                if nw_path_uses_interface_type(path, nw_interface_type_wifi) {
                    "wifi"
                } else if nw_path_uses_interface_type(path, nw_interface_type_cellular) {
                    "cellular"
                } else if nw_path_uses_interface_type(path, nw_interface_type_wired) {
                    "ethernet"
                } else {
                    "other"
                }
            } else if status == nw_path_status_unsatisfied {
                "no_connection"
            } else {
                "unknown"
            };
            if let Ok(mut guard) = (*storage_for_block).lock() {
                *guard = Some(network_type.to_string());
            }
        });

        let queue = DispatchQueue::new("com.xuehua.networkmonitor", DispatchQueueAttr::SERIAL);
        let queue_ptr = dispatch2::DispatchRetained::as_ptr(&queue).as_ptr() as dispatch_queue_t;

        nw_path_monitor_set_queue(monitor, queue_ptr);
        nw_path_monitor_set_update_handler(
            monitor,
            RcBlock::as_ptr(&block) as *const block2::Block<dyn Fn(nw_path_t)>,
        );
        nw_path_monitor_start(monitor);

        for _ in 0..10 {
            if storage
                .lock()
                .ok()
                .and_then(|guard| guard.clone())
                .is_some()
            {
                break;
            }
            std::thread::sleep(std::time::Duration::from_millis(50));
        }

        nw_path_monitor_cancel(monitor);
        nw_release(monitor.cast());

        storage
            .lock()
            .ok()
            .and_then(|guard| guard.clone())
            .unwrap_or_else(|| "unknown".to_string())
    }
}

fn get_ip_address() -> Option<String> {
    unsafe {
        let mut ifaddr: *mut libc::ifaddrs = std::ptr::null_mut();
        if libc::getifaddrs(&mut ifaddr) != 0 {
            return None;
        }

        let mut result: Option<String> = None;
        let mut current = ifaddr;

        while !current.is_null() {
            let interface = &*current;
            if !interface.ifa_addr.is_null() {
                let family = (*interface.ifa_addr).sa_family;
                if family == libc::AF_INET as u8 {
                    let name = CStr::from_ptr(interface.ifa_name).to_str().unwrap_or("");
                    if name == "en0" || name == "pdp_ip0" {
                        let mut hostname = [0u8; libc::NI_MAXHOST as usize];
                        if libc::getnameinfo(
                            interface.ifa_addr,
                            (*interface.ifa_addr).sa_len as u32,
                            hostname.as_mut_ptr() as *mut _,
                            hostname.len() as u32,
                            std::ptr::null_mut(),
                            0,
                            libc::NI_NUMERICHOST,
                        ) == 0
                        {
                            let ip = CStr::from_ptr(hostname.as_ptr() as *const _)
                                .to_str()
                                .ok()
                                .map(|s| s.to_string());
                            if name == "en0" {
                                libc::freeifaddrs(ifaddr);
                                return ip;
                            }
                            result = ip;
                        }
                    }
                }
            }
            current = interface.ifa_next;
        }

        libc::freeifaddrs(ifaddr);
        result
    }
}
