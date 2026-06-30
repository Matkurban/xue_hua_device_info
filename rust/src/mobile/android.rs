//! Android device information via JNI.

use crate::models::*;
use jni::{
    objects::{JByteArray, JObject, JValue},
    sys::jint,
    Env,
    errors::Result as JniResult,
    jni_sig, jni_str,
};

use super::jni_helpers::{
    application_context, get_system_service, intent_get_int_extra, java_string_to_rust,
    jstring_from_rust, settings_global_get_string, settings_secure_get_string, with_env,
};

const BATTERY_PROPERTY_CAPACITY: jint = 4;
const BATTERY_STATUS_CHARGING: jint = 2;
const BATTERY_STATUS_FULL: jint = 5;
const BATTERY_HEALTH_UNKNOWN: jint = 1;
const BATTERY_HEALTH_GOOD: jint = 2;
const BATTERY_HEALTH_OVERHEAT: jint = 3;
const BATTERY_HEALTH_DEAD: jint = 4;
const BATTERY_HEALTH_OVER_VOLTAGE: jint = 5;
const BATTERY_HEALTH_UNSPECIFIED_FAILURE: jint = 6;
const BATTERY_HEALTH_COLD: jint = 7;
const TRANSPORT_WIFI: jint = 1;
const TRANSPORT_CELLULAR: jint = 0;
const TRANSPORT_ETHERNET: jint = 3;
const DISPLAY_DEFAULT: jint = 0;

fn map_battery_health(health: jint) -> String {
    match health {
        BATTERY_HEALTH_GOOD => "Good".to_string(),
        BATTERY_HEALTH_OVERHEAT => "Overheat".to_string(),
        BATTERY_HEALTH_DEAD => "Dead".to_string(),
        BATTERY_HEALTH_OVER_VOLTAGE => "Over Voltage".to_string(),
        BATTERY_HEALTH_UNSPECIFIED_FAILURE => "Unspecified Failure".to_string(),
        BATTERY_HEALTH_COLD => "Cold".to_string(),
        _ => "Unknown".to_string(),
    }
}

fn normalize_battery_level(raw: jint) -> Option<f32> {
    if (0..=100).contains(&raw) {
        Some(raw as f32)
    } else {
        None
    }
}

pub fn get_device_info() -> crate::Result<DeviceInfoResponse> {
    with_env(|env| {
        let context = application_context(env)?;
        let android_id =
            settings_secure_get_string(env, &context, "android_id")?.unwrap_or_default();
        let device_name = settings_global_get_string(env, &context, "device_name")?
            .or_else(|| settings_secure_get_string(env, &context, "bluetooth_name").ok().flatten());
        let manufacturer_obj = env
            .get_static_field(
                jni_str!("android/os/Build"),
                jni_str!("MANUFACTURER"),
                jni_sig!("Ljava/lang/String;"),
            )?
            .l()?;
        let manufacturer = java_string_to_rust(env, manufacturer_obj)?;
        let model_obj = env
            .get_static_field(
                jni_str!("android/os/Build"),
                jni_str!("MODEL"),
                jni_sig!("Ljava/lang/String;"),
            )?
            .l()?;
        let model = java_string_to_rust(env, model_obj)?;

        Ok(DeviceInfoResponse {
            uuid: Some(android_id.clone()),
            manufacturer: Some(manufacturer),
            model: Some(model),
            serial: Some(android_id.clone()),
            android_id: Some(android_id),
            device_name,
        })
    })
    .map_err(crate::Error::DeviceInfo)
}

pub fn get_battery_info() -> crate::Result<BatteryInfo> {
    with_env(|env| {
        let context = application_context(env)?;
        let battery_manager = get_system_service(env, &context, "batterymanager")?;

        let raw_level = env
            .call_method(
                &battery_manager,
                jni_str!("getIntProperty"),
                jni_sig!("(I)I"),
                &[JValue::Int(BATTERY_PROPERTY_CAPACITY)],
            )?
            .i()?;
        let level = normalize_battery_level(raw_level);

        let action_string = jstring_from_rust(env, "android.intent.action.BATTERY_CHANGED")?;
        let filter = env.new_object(
            jni_str!("android/content/IntentFilter"),
            jni_sig!("(Ljava/lang/String;)V"),
            &[JValue::Object(&action_string)],
        )?;

        let battery_status = env
            .call_method(
                &context,
                jni_str!("registerReceiver"),
                jni_sig!(
                    "(Landroid/content/BroadcastReceiver;Landroid/content/IntentFilter;)Landroid/content/Intent;"
                ),
                &[JValue::Object(&JObject::null()), JValue::Object(&filter)],
            )?
            .l()?;

        let (is_charging, health) = if battery_status.is_null() {
            (None, None)
        } else {
            let status = intent_get_int_extra(env, &battery_status, "status", -1)?;
            let charging = status == BATTERY_STATUS_CHARGING || status == BATTERY_STATUS_FULL;
            let health_int =
                intent_get_int_extra(env, &battery_status, "health", BATTERY_HEALTH_UNKNOWN)?;
            (Some(charging), Some(map_battery_health(health_int)))
        };

        Ok(BatteryInfo {
            level,
            is_charging,
            health,
        })
    })
    .map_err(crate::Error::DeviceInfo)
}

pub fn get_network_info() -> crate::Result<NetworkInfo> {
    with_env(|env| {
        let context = application_context(env)?;
        let connectivity = get_system_service(env, &context, "connectivity")?;

        let active_network = env
            .call_method(
                &connectivity,
                jni_str!("getActiveNetwork"),
                jni_sig!("()Landroid/net/Network;"),
                &[],
            )?
            .l()?;

        let network_type = if active_network.is_null() {
            "unknown".to_string()
        } else {
            let capabilities = env
                .call_method(
                    &connectivity,
                    jni_str!("getNetworkCapabilities"),
                    jni_sig!("(Landroid/net/Network;)Landroid/net/NetworkCapabilities;"),
                    &[JValue::Object(&active_network)],
                )?
                .l()?;

            if capabilities.is_null() {
                "unknown".to_string()
            } else if env
                .call_method(
                    &capabilities,
                    jni_str!("hasTransport"),
                    jni_sig!("(I)Z"),
                    &[JValue::Int(TRANSPORT_WIFI)],
                )?
                .z()?
            {
                "wifi".to_string()
            } else if env
                .call_method(
                    &capabilities,
                    jni_str!("hasTransport"),
                    jni_sig!("(I)Z"),
                    &[JValue::Int(TRANSPORT_CELLULAR)],
                )?
                .z()?
            {
                "cellular".to_string()
            } else if env
                .call_method(
                    &capabilities,
                    jni_str!("hasTransport"),
                    jni_sig!("(I)Z"),
                    &[JValue::Int(TRANSPORT_ETHERNET)],
                )?
                .z()?
            {
                "ethernet".to_string()
            } else {
                "unknown".to_string()
            }
        };

        let ip_address = if active_network.is_null() {
            None
        } else {
            let link_properties = env
                .call_method(
                    &connectivity,
                    jni_str!("getLinkProperties"),
                    jni_sig!("(Landroid/net/Network;)Landroid/net/LinkProperties;"),
                    &[JValue::Object(&active_network)],
                )?
                .l()?;

            if link_properties.is_null() {
                None
            } else {
                find_ipv4_address(env, &link_properties)?
            }
        };

        Ok(NetworkInfo {
            ip_address,
            network_type: Some(network_type),
            mac_address: Some("restricted".to_string()),
        })
    })
    .map_err(crate::Error::DeviceInfo)
}

fn find_ipv4_address<'local>(
    env: &mut Env<'local>,
    link_properties: &JObject<'local>,
) -> JniResult<Option<String>> {
    let addresses = env
        .call_method(
            link_properties,
            jni_str!("getLinkAddresses"),
            jni_sig!("()Ljava/util/List;"),
            &[],
        )?
        .l()?;

    if addresses.is_null() {
        return Ok(None);
    }

    let size = env
        .call_method(&addresses, jni_str!("size"), jni_sig!("()I"), &[])?
        .i()?;
    for i in 0..size {
        let link_address = env
            .call_method(
                &addresses,
                jni_str!("get"),
                jni_sig!("(I)Ljava/lang/Object;"),
                &[JValue::Int(i)],
            )?
            .l()?;

        if link_address.is_null() {
            continue;
        }

        let addr = env
            .call_method(
                &link_address,
                jni_str!("getAddress"),
                jni_sig!("()Ljava/net/InetAddress;"),
                &[],
            )?
            .l()?;

        if addr.is_null() {
            continue;
        }

        let bytes = env
            .call_method(&addr, jni_str!("getAddress"), jni_sig!("()[B"), &[])?
            .l()?;

        if bytes.is_null() {
            continue;
        }

        let byte_array = unsafe { JByteArray::from_raw(env, bytes.as_raw()) };
        let len = env.get_array_length(&byte_array)?;
        if len == 4 {
            let host = env
                .call_method(
                    &addr,
                    jni_str!("getHostAddress"),
                    jni_sig!("()Ljava/lang/String;"),
                    &[],
                )?
                .l()?;
            if !host.is_null() {
                return java_string_to_rust(env, host).map(Some);
            }
        }
    }

    Ok(None)
}

pub fn get_storage_info() -> crate::Result<StorageInfo> {
    with_env(|env| {
        let data_dir = env
            .call_static_method(
                jni_str!("android/os/Environment"),
                jni_str!("getDataDirectory"),
                jni_sig!("()Ljava/io/File;"),
                &[],
            )?
            .l()?;

        let path = env
            .call_method(
                &data_dir,
                jni_str!("getPath"),
                jni_sig!("()Ljava/lang/String;"),
                &[],
            )?
            .l()?;

        let stat = env.new_object(
            jni_str!("android/os/StatFs"),
            jni_sig!("(Ljava/lang/String;)V"),
            &[JValue::Object(&path)],
        )?;

        let total_space = env
            .call_method(&stat, jni_str!("getTotalBytes"), jni_sig!("()J"), &[])?
            .j()? as u64;
        let free_space = env
            .call_method(
                &stat,
                jni_str!("getAvailableBytes"),
                jni_sig!("()J"),
                &[],
            )?
            .j()? as u64;

        Ok(StorageInfo {
            total_space,
            free_space,
            storage_type: Some("internal".to_string()),
        })
    })
    .map_err(crate::Error::DeviceInfo)
}

pub fn get_display_info() -> crate::Result<DisplayInfo> {
    with_env(|env| {
        let context = application_context(env)?;

        let resources = env
            .call_method(
                &context,
                jni_str!("getResources"),
                jni_sig!("()Landroid/content/res/Resources;"),
                &[],
            )?
            .l()?;

        let metrics = env
            .call_method(
                &resources,
                jni_str!("getDisplayMetrics"),
                jni_sig!("()Landroid/util/DisplayMetrics;"),
                &[],
            )?
            .l()?;

        let width = env
            .get_field(&metrics, jni_str!("widthPixels"), jni_sig!("I"))?
            .i()? as u32;
        let height = env
            .get_field(&metrics, jni_str!("heightPixels"), jni_sig!("I"))?
            .i()? as u32;
        let density = env
            .get_field(&metrics, jni_str!("density"), jni_sig!("F"))?
            .f()? as f64;

        let display_manager = get_system_service(env, &context, "display")?;
        let display = env
            .call_method(
                &display_manager,
                jni_str!("getDisplay"),
                jni_sig!("(I)Landroid/view/Display;"),
                &[JValue::Int(DISPLAY_DEFAULT)],
            )?
            .l()?;

        let refresh_rate = if display.is_null() {
            Some(60.0)
        } else {
            Some(
                env.call_method(
                    &display,
                    jni_str!("getRefreshRate"),
                    jni_sig!("()F"),
                    &[],
                )?
                .f()? as f64,
            )
        };

        Ok(DisplayInfo {
            width,
            height,
            scale_factor: density,
            refresh_rate,
        })
    })
    .map_err(crate::Error::DeviceInfo)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_battery_level_filters_invalid() {
        assert_eq!(normalize_battery_level(-1), None);
        assert_eq!(normalize_battery_level(0), Some(0.0));
        assert_eq!(normalize_battery_level(85), Some(85.0));
        assert_eq!(normalize_battery_level(101), None);
    }

    #[test]
    fn map_battery_health_values() {
        assert_eq!(map_battery_health(BATTERY_HEALTH_GOOD), "Good");
        assert_eq!(map_battery_health(99), "Unknown");
    }
}
