//! Platform dispatch and shared interface at the FFI seam.

use crate::models::*;

/// Platform adapter interface — one implementation per target family.
pub trait PlatformDeviceInfo {
    fn get_device_info(&self) -> crate::Result<DeviceInfoResponse>;
    fn get_battery_info(&self) -> crate::Result<BatteryInfo>;
    fn get_network_info(&self) -> crate::Result<NetworkInfo>;
    fn get_storage_info(&self) -> crate::Result<StorageInfo>;
    fn get_display_info(&self) -> crate::Result<DisplayInfo>;
}

#[cfg(not(any(target_os = "ios", target_os = "android")))]
struct DesktopAdapter;

#[cfg(not(any(target_os = "ios", target_os = "android")))]
impl PlatformDeviceInfo for DesktopAdapter {
    fn get_device_info(&self) -> crate::Result<DeviceInfoResponse> {
        crate::desktop::get_device_info()
    }
    fn get_battery_info(&self) -> crate::Result<BatteryInfo> {
        crate::desktop::get_battery_info()
    }
    fn get_network_info(&self) -> crate::Result<NetworkInfo> {
        crate::desktop::get_network_info()
    }
    fn get_storage_info(&self) -> crate::Result<StorageInfo> {
        crate::desktop::get_storage_info()
    }
    fn get_display_info(&self) -> crate::Result<DisplayInfo> {
        crate::desktop::get_display_info()
    }
}

#[cfg(target_os = "ios")]
struct IosAdapter;

#[cfg(target_os = "ios")]
impl PlatformDeviceInfo for IosAdapter {
    fn get_device_info(&self) -> crate::Result<DeviceInfoResponse> {
        crate::mobile::ios::get_device_info()
    }
    fn get_battery_info(&self) -> crate::Result<BatteryInfo> {
        crate::mobile::ios::get_battery_info()
    }
    fn get_network_info(&self) -> crate::Result<NetworkInfo> {
        crate::mobile::ios::get_network_info()
    }
    fn get_storage_info(&self) -> crate::Result<StorageInfo> {
        crate::mobile::ios::get_storage_info()
    }
    fn get_display_info(&self) -> crate::Result<DisplayInfo> {
        crate::mobile::ios::get_display_info()
    }
}

#[cfg(target_os = "android")]
struct AndroidAdapter;

#[cfg(target_os = "android")]
impl PlatformDeviceInfo for AndroidAdapter {
    fn get_device_info(&self) -> crate::Result<DeviceInfoResponse> {
        crate::mobile::android::get_device_info()
    }
    fn get_battery_info(&self) -> crate::Result<BatteryInfo> {
        crate::mobile::android::get_battery_info()
    }
    fn get_network_info(&self) -> crate::Result<NetworkInfo> {
        crate::mobile::android::get_network_info()
    }
    fn get_storage_info(&self) -> crate::Result<StorageInfo> {
        crate::mobile::android::get_storage_info()
    }
    fn get_display_info(&self) -> crate::Result<DisplayInfo> {
        crate::mobile::android::get_display_info()
    }
}

#[cfg(not(any(target_os = "ios", target_os = "android")))]
fn adapter() -> &'static dyn PlatformDeviceInfo {
    static DESKTOP: DesktopAdapter = DesktopAdapter;
    &DESKTOP
}

#[cfg(target_os = "ios")]
fn adapter() -> &'static dyn PlatformDeviceInfo {
    static IOS: IosAdapter = IosAdapter;
    &IOS
}

#[cfg(target_os = "android")]
fn adapter() -> &'static dyn PlatformDeviceInfo {
    static ANDROID: AndroidAdapter = AndroidAdapter;
    &ANDROID
}

pub fn get_device_info() -> crate::Result<DeviceInfoResponse> {
    adapter().get_device_info()
}

pub fn get_battery_info() -> crate::Result<BatteryInfo> {
    adapter().get_battery_info()
}

pub fn get_network_info() -> crate::Result<NetworkInfo> {
    adapter().get_network_info()
}

pub fn get_storage_info() -> crate::Result<StorageInfo> {
    adapter().get_storage_info()
}

pub fn get_display_info() -> crate::Result<DisplayInfo> {
    adapter().get_display_info()
}
