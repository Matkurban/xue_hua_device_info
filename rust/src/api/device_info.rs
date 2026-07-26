use crate::models::*;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[flutter_rust_bridge::frb]
pub fn get_device_info() -> Result<DeviceInfoResponse, String> {
    crate::platform::get_device_info().map_err(|e| e.to_string())
}

#[flutter_rust_bridge::frb]
pub fn get_battery_info() -> Result<BatteryInfo, String> {
    crate::platform::get_battery_info().map_err(|e| e.to_string())
}

#[flutter_rust_bridge::frb]
pub fn get_network_info() -> Result<NetworkInfo, String> {
    crate::platform::get_network_info().map_err(|e| e.to_string())
}

#[flutter_rust_bridge::frb]
pub fn get_storage_info() -> Result<StorageInfo, String> {
    crate::platform::get_storage_info().map_err(|e| e.to_string())
}

#[flutter_rust_bridge::frb]
pub fn get_display_info() -> Result<DisplayInfo, String> {
    crate::platform::get_display_info().map_err(|e| e.to_string())
}

