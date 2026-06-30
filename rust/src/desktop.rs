//! Desktop platform implementation for device information.
//!
//! - **Windows**: WMI
//! - **macOS**: `system_profiler` and CoreGraphics
//! - **Linux**: `/sys/class/dmi/id/` and `xrandr`

use crate::models::*;

#[cfg(target_os = "windows")]
mod windows;

#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "linux")]
mod linux;

pub fn get_device_info() -> crate::Result<DeviceInfoResponse> {
    #[cfg(target_os = "windows")]
    return windows::get_device_info();

    #[cfg(target_os = "macos")]
    return macos::get_device_info();

    #[cfg(target_os = "linux")]
    return linux::get_device_info();

    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    return Err(crate::Error::DeviceInfo("Unsupported platform".to_string()));
}

pub fn get_battery_info() -> crate::Result<BatteryInfo> {
    #[cfg(target_os = "macos")]
    return macos::get_battery_info();

    #[cfg(not(target_os = "macos"))]
    {
        let manager =
            battery::Manager::new().map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        if let Some(Ok(battery)) = manager
            .batteries()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .next()
        {
            let level = (battery.state_of_charge().value * 100.0).round();
            let is_charging = matches!(
                battery.state(),
                battery::State::Charging | battery::State::Full
            );
            let health = format!("{:?}", battery.state_of_health().value * 100.0);

            Ok(BatteryInfo {
                level: Some(level),
                is_charging: Some(is_charging),
                health: Some(health),
            })
        } else {
            Ok(BatteryInfo::default())
        }
    }
}

fn classify_macos_interface(name: &str) -> Option<String> {
    #[cfg(target_os = "macos")]
    {
        return macos::classify_interface_name(name);
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = name;
        None
    }
}

fn get_default_mac_address() -> Option<String> {
    use default_net::get_default_interface;
    match get_default_interface() {
        Ok(interface) => interface.mac_addr.map(|mac| mac.to_string()),
        Err(_) => None,
    }
}

pub fn get_network_info() -> crate::Result<NetworkInfo> {
    use local_ip_address::local_ip;
    let ip_addr = local_ip().ok();
    let ip_str = ip_addr.map(|ip| ip.to_string());

    let mac_address = get_default_mac_address();

    let mut network_type = Some("unknown".to_string());

    if let Some(target_ip) = ip_addr {
        let networks = sysinfo::Networks::new_with_refreshed_list();

        if let Some((name, _)) = networks.iter().find(|(_, network)| {
            network
                .ip_networks()
                .iter()
                .any(|net| net.addr == target_ip)
        }) {
            let name_lower = name.to_lowercase();
            if name_lower.contains("wifi") || name_lower.contains("wl") {
                network_type = Some("wifi".to_string());
            } else if name_lower.contains("eth") || name_lower.contains("ethernet") {
                network_type = Some("ethernet".to_string());
            } else if let Some(kind) = classify_macos_interface(name) {
                network_type = Some(kind);
            } else {
                network_type = Some(name.to_string());
            }
        }
    }

    Ok(NetworkInfo {
        ip_address: ip_str,
        network_type,
        mac_address,
    })
}

fn format_storage_type(kind: sysinfo::DiskKind) -> String {
    match kind {
        sysinfo::DiskKind::SSD => "Ssd".to_string(),
        sysinfo::DiskKind::HDD => "Hdd".to_string(),
        sysinfo::DiskKind::Unknown(_) => "Unknown".to_string(),
    }
}

pub fn get_storage_info() -> crate::Result<StorageInfo> {
    let disks = sysinfo::Disks::new_with_refreshed_list();

    let system_disk = disks.iter().find(|d| {
        let mount = d.mount_point();
        mount == std::path::Path::new("/") || mount == std::path::Path::new("C:\\")
    });

    let targeted_disk = system_disk.or_else(|| disks.iter().max_by_key(|d| d.total_space()));

    if let Some(disk) = targeted_disk {
        Ok(StorageInfo {
            total_space: disk.total_space(),
            free_space: disk.available_space(),
            storage_type: Some(format_storage_type(disk.kind())),
        })
    } else {
        Ok(StorageInfo::default())
    }
}

pub fn get_display_info() -> crate::Result<DisplayInfo> {
    #[cfg(target_os = "macos")]
    {
        use core_graphics::display::CGDisplay;

        let main_display = CGDisplay::main();
        let bounds = main_display.bounds();
        let pixel_width = main_display.pixels_wide();
        let pixel_height = main_display.pixels_high();
        let scale_factor = if bounds.size.width > 0.0 {
            pixel_width as f64 / bounds.size.width as f64
        } else {
            1.0
        };

        return Ok(DisplayInfo {
            width: pixel_width as u32,
            height: pixel_height as u32,
            scale_factor,
            refresh_rate: macos::get_display_refresh_rate(),
        });
    }

    #[cfg(target_os = "windows")]
    {
        use winapi::um::shellscalingapi::GetDpiForSystem;
        use winapi::um::winuser::{GetSystemMetrics, SM_CXSCREEN, SM_CYSCREEN};

        let width = unsafe { GetSystemMetrics(SM_CXSCREEN) } as u32;
        let height = unsafe { GetSystemMetrics(SM_CYSCREEN) } as u32;
        let dpi = unsafe { GetDpiForSystem() };
        let scale_factor = dpi as f64 / 96.0;

        return Ok(DisplayInfo {
            width,
            height,
            scale_factor,
            refresh_rate: windows::get_display_refresh_rate(),
        });
    }

    #[cfg(target_os = "linux")]
    {
        if let Some((width, height)) = linux::get_display_resolution() {
            return Ok(DisplayInfo {
                width,
                height,
                scale_factor: 1.0,
                refresh_rate: linux::get_display_refresh_rate(),
            });
        }
        return Ok(DisplayInfo::default());
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    Ok(DisplayInfo::default())
}
