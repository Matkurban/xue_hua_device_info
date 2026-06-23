use crate::models::*;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

async fn run_blocking<F, T>(f: F) -> Result<T, String>
where
    F: FnOnce() -> crate::Result<T> + Send + 'static,
    T: Send + 'static,
{
    tokio::task::spawn_blocking(f)
        .await
        .map_err(|e| e.to_string())?
        .map_err(|e| e.to_string())
}

#[flutter_rust_bridge::frb]
pub async fn get_device_info() -> Result<DeviceInfoResponse, String> {
    run_blocking(|| {
        #[cfg(not(target_os = "ios"))]
        return crate::desktop::get_device_info();

        #[cfg(target_os = "ios")]
        return crate::mobile::ios::get_device_info();
    })
    .await
}

#[flutter_rust_bridge::frb]
pub async fn get_battery_info() -> Result<BatteryInfo, String> {
    run_blocking(|| {
        #[cfg(not(target_os = "ios"))]
        return crate::desktop::get_battery_info();

        #[cfg(target_os = "ios")]
        return crate::mobile::ios::get_battery_info();
    })
    .await
}

#[flutter_rust_bridge::frb]
pub async fn get_network_info() -> Result<NetworkInfo, String> {
    run_blocking(|| {
        #[cfg(not(target_os = "ios"))]
        return crate::desktop::get_network_info();

        #[cfg(target_os = "ios")]
        return crate::mobile::ios::get_network_info();
    })
    .await
}

#[flutter_rust_bridge::frb]
pub async fn get_storage_info() -> Result<StorageInfo, String> {
    run_blocking(|| {
        #[cfg(not(target_os = "ios"))]
        return crate::desktop::get_storage_info();

        #[cfg(target_os = "ios")]
        return crate::mobile::ios::get_storage_info();
    })
    .await
}

#[flutter_rust_bridge::frb]
pub async fn get_display_info() -> Result<DisplayInfo, String> {
    run_blocking(|| {
        #[cfg(not(target_os = "ios"))]
        return crate::desktop::get_display_info();

        #[cfg(target_os = "ios")]
        return crate::mobile::ios::get_display_info();
    })
    .await
}
