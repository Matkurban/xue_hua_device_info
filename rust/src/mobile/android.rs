//! Android device info via JNI.
//!
//! Requires `xue_hua_device_info_init_java_vm` to be called from Kotlin before use.

use crate::models::*;
use jni::objects::{JClass, JObject, JValue};
use jni::sys::jint;
use jni::{JNIEnv, JavaVM};
use std::sync::OnceLock;

static JAVA_VM: OnceLock<JavaVM> = OnceLock::new();

fn store_java_vm(vm: JavaVM) {
    let _ = JAVA_VM.set(vm);
}

/// Called when the JVM loads the library via `System.loadLibrary`.
#[no_mangle]
pub extern "system" fn JNI_OnLoad(vm: JavaVM, _: *mut std::ffi::c_void) -> jint {
    store_java_vm(vm);
    jni::JNIVersion::V6.into()
}

/// Called from Kotlin plugin during `onAttachedToEngine`.
#[no_mangle]
pub extern "system" fn xue_hua_device_info_init_java_vm(vm: *mut jni::sys::JavaVM) {
    if vm.is_null() {
        return;
    }
    unsafe {
        if let Ok(jvm) = JavaVM::from_raw(vm) {
            store_java_vm(jvm);
        }
    }
}

/// JNI entry point for [XueHuaDeviceInfoPlugin.initJavaVm].
#[no_mangle]
pub extern "system" fn Java_com_flutter_rust_bridge_xue_hua_1device_1info_XueHuaDeviceInfoPlugin_initJavaVm<'local>(
    env: JNIEnv<'local>,
    _class: JClass<'local>,
) {
    if let Ok(vm) = env.get_java_vm() {
        store_java_vm(vm);
    }
}

fn with_env<F, T>(f: F) -> crate::Result<T>
where
    F: FnOnce(&mut JNIEnv) -> crate::Result<T>,
{
    let vm = JAVA_VM
        .get()
        .ok_or_else(|| crate::Error::DeviceInfo("JavaVM not initialized".to_string()))?;
    let mut env = vm
        .attach_current_thread()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    f(&mut env)
}
pub fn get_device_info() -> crate::Result<DeviceInfoResponse> {
    with_env(|env| {
        let context = get_application_context(env)?;

        let android_id = get_secure_setting(env, &context, "android_id")?;
        let device_name = get_global_setting(env, &context, "device_name")
            .ok()
            .flatten()
            .or_else(|| get_secure_setting(env, &context, "bluetooth_name").ok().flatten());

        let manufacturer = get_build_field(env, "MANUFACTURER")?;
        let model = get_build_field(env, "MODEL")?;

        Ok(DeviceInfoResponse {
            uuid: android_id.clone(),
            manufacturer,
            model,
            serial: android_id.clone(),
            android_id,
            device_name,
        })
    })
}

pub fn get_battery_info() -> crate::Result<BatteryInfo> {
    with_env(|env| {
        let context = get_application_context(env)?;

        let service_name = env
            .new_string("power")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let bm = env
            .call_method(
                &context,
                "getSystemService",
                "(Ljava/lang/String;)Ljava/lang/Object;",
                &[JValue::Object(&service_name)],
            )
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let level = {
            let prop_capacity: jint = 4; // BatteryManager.BATTERY_PROPERTY_CAPACITY
            let level_val = env
                .call_method(
                    &bm,
                    "getIntProperty",
                    "(I)I",
                    &[JValue::Int(prop_capacity)],
                )
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
                .i()
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
            Some(level_val as f32)
        };

        // Sticky battery intent
        let intent_filter = env
            .find_class("android/content/IntentFilter")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let filter = env
            .new_object(intent_filter, "()V", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let action = env
            .new_string("android.intent.action.BATTERY_CHANGED")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        env.call_method(
            &filter,
            "addAction",
            "(Ljava/lang/String;)V",
            &[JValue::Object(&action)],
        )
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let intent = env
            .call_method(
                &context,
                "registerReceiver",
                "(Landroid/content/BroadcastReceiver;Landroid/content/IntentFilter;)Landroid/content/Intent;",
                &[JValue::Object(&JObject::null()), JValue::Object(&filter)],
            )
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let (is_charging, health) = if !intent.is_null() {
            let status = get_int_extra(env, &intent, "status", -1)?;
            let is_charging = status == 2 || status == 5; // CHARGING or FULL
            let health_int = get_int_extra(env, &intent, "health", -1)?;
            let health_str = match health_int {
                2 => "Good",
                3 => "Overheat",
                4 => "Dead",
                5 => "Over Voltage",
                6 => "Unspecified Failure",
                7 => "Cold",
                _ => "Unknown",
            };
            (Some(is_charging), Some(health_str.to_string()))
        } else {
            (None, None)
        };

        Ok(BatteryInfo {
            level,
            is_charging,
            health,
        })
    })
}

pub fn get_network_info() -> crate::Result<NetworkInfo> {
    with_env(|env| {
        let context = get_application_context(env)?;
        let conn_name = env
            .new_string("connectivity")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let cm = env
            .call_method(
                &context,
                "getSystemService",
                "(Ljava/lang/String;)Ljava/lang/Object;",
                &[JValue::Object(&conn_name)],
            )
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let active_network = env
            .call_method(&cm, "getActiveNetwork", "()Landroid/net/Network;", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let capabilities = env
            .call_method(
                &cm,
                "getNetworkCapabilities",
                "(Landroid/net/Network;)Landroid/net/NetworkCapabilities;",
                &[JValue::Object(&active_network)],
            )
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let network_type = if !capabilities.is_null() {
            let wifi = has_transport(env, &capabilities, 1)?;
            let cellular = has_transport(env, &capabilities, 0)?;
            let ethernet = has_transport(env, &capabilities, 3)?;
            if wifi {
                "wifi".to_string()
            } else if cellular {
                "cellular".to_string()
            } else if ethernet {
                "ethernet".to_string()
            } else {
                "unknown".to_string()
            }
        } else {
            "unknown".to_string()
        };

        let link_props = env
            .call_method(
                &cm,
                "getLinkProperties",
                "(Landroid/net/Network;)Landroid/net/LinkProperties;",
                &[JValue::Object(&active_network)],
            )
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let ip_address = if !link_props.is_null() {
            get_ipv4_from_link_properties(env, &link_props)?
        } else {
            "0.0.0.0".to_string()
        };

        Ok(NetworkInfo {
            ip_address: Some(ip_address),
            network_type: Some(network_type),
            mac_address: Some("restricted".to_string()),
        })
    })
}

pub fn get_storage_info() -> crate::Result<StorageInfo> {
    with_env(|env| {
        let data_dir = env
            .find_class("android/os/Environment")
            .and_then(|cls| {
                env.call_static_method(
                    cls,
                    "getDataDirectory",
                    "()Ljava/io/File;",
                    &[],
                )
            })
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let path = env
            .call_method(&data_dir, "getPath", "()Ljava/lang/String;", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let path_str: String = env
            .get_string(&path.into())
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .into();

        let path_j = env
            .new_string(&path_str)
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let stat_cls = env
            .find_class("android/os/StatFs")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let stat = env
            .new_object(stat_cls, "(Ljava/lang/String;)V", &[JValue::Object(&path_j)])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let total = env
            .call_method(&stat, "getTotalBytes", "()J", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .j()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))? as u64;
        let free = env
            .call_method(&stat, "getAvailableBytes", "()J", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .j()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))? as u64;

        Ok(StorageInfo {
            total_space: total,
            free_space: free,
            storage_type: Some("internal".to_string()),
        })
    })
}

pub fn get_display_info() -> crate::Result<DisplayInfo> {
    with_env(|env| {
        let context = get_application_context(env)?;

        let resources = env
            .call_method(&context, "getResources", "()Landroid/content/res/Resources;", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let metrics_cls = env
            .find_class("android/util/DisplayMetrics")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let metrics = env
            .new_object(metrics_cls, "()V", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        env.call_method(
            &resources,
            "getDisplayMetrics",
            "(Landroid/util/DisplayMetrics;)V",
            &[JValue::Object(&metrics)],
        )
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let width = env
            .get_field(&metrics, "widthPixels", "I")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .i()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))? as u32;
        let height = env
            .get_field(&metrics, "heightPixels", "I")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .i()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))? as u32;
        let density = env
            .get_field(&metrics, "density", "F")
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .f()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))? as f64;

        let refresh_rate = {
            let wm_name = env
                .new_string("window")
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
            let wm = env
                .call_method(
                    &context,
                    "getSystemService",
                    "(Ljava/lang/String;)Ljava/lang/Object;",
                    &[JValue::Object(&wm_name)],
                )
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
                .l()
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

            let display = env
                .call_method(&wm, "getDefaultDisplay", "()Landroid/view/Display;", &[])
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
                .l()
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

            env.call_method(&display, "getRefreshRate", "()F", &[])
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
                .f()
                .map_err(|e| crate::Error::DeviceInfo(e.to_string()))? as f64
        };

        Ok(DisplayInfo {
            width,
            height,
            scale_factor: density,
            refresh_rate: Some(refresh_rate),
        })
    })
}

// --- JNI helpers ---

fn get_application_context<'local>(env: &mut JNIEnv<'local>) -> crate::Result<JObject<'local>> {
    let activity_thread = env
        .find_class("android/app/ActivityThread")
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let app = env
        .call_static_method(
            activity_thread,
            "currentApplication",
            "()Landroid/app/Application;",
            &[],
        )
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .l()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    Ok(app)
}

fn get_secure_setting(
    env: &mut JNIEnv,
    context: &JObject,
    key: &str,
) -> crate::Result<Option<String>> {
    let resolver = env
        .call_method(context, "getContentResolver", "()Landroid/content/ContentResolver;", &[])
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .l()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let settings = env
        .find_class("android/provider/Settings$Secure")
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let key_j = env
        .new_string(key)
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let result = env
        .call_static_method(
            settings,
            "getString",
            "(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;",
            &[JValue::Object(&resolver), JValue::Object(&key_j)],
        )
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .l()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    if result.is_null() {
        Ok(None)
    } else {
        let s: String = env
            .get_string(&result.into())
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .into();
        Ok(Some(s))
    }
}

fn get_global_setting(
    env: &mut JNIEnv,
    context: &JObject,
    key: &str,
) -> crate::Result<Option<String>> {
    let resolver = env
        .call_method(context, "getContentResolver", "()Landroid/content/ContentResolver;", &[])
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .l()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let settings = env
        .find_class("android/provider/Settings$Global")
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let key_j = env
        .new_string(key)
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let result = env
        .call_static_method(
            settings,
            "getString",
            "(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;",
            &[JValue::Object(&resolver), JValue::Object(&key_j)],
        )
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .l()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    if result.is_null() {
        Ok(None)
    } else {
        let s: String = env
            .get_string(&result.into())
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .into();
        Ok(Some(s))
    }
}

fn get_build_field(env: &mut JNIEnv, field: &str) -> crate::Result<Option<String>> {
    let build = env
        .find_class("android/os/Build")
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    let val = env
        .get_static_field(build, field, "Ljava/lang/String;")
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .l()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    if val.is_null() {
        Ok(None)
    } else {
        let s: String = env
            .get_string(&val.into())
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .into();
        Ok(Some(s))
    }
}

fn get_int_extra(env: &mut JNIEnv, intent: &JObject, key: &str, default: jint) -> crate::Result<jint> {
    let key_j = env
        .new_string(key)
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    env.call_method(
        intent,
        "getIntExtra",
        "(Ljava/lang/String;I)I",
        &[JValue::Object(&key_j), JValue::Int(default)],
    )
    .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
    .i()
    .map_err(|e| crate::Error::DeviceInfo(e.to_string()))
}

fn has_transport(env: &mut JNIEnv, capabilities: &JObject, transport: jint) -> crate::Result<bool> {
    let result = env
        .call_method(
            capabilities,
            "hasTransport",
            "(I)Z",
            &[JValue::Int(transport)],
        )
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .z()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
    Ok(result)
}

fn get_ipv4_from_link_properties(env: &mut JNIEnv, link_props: &JObject) -> crate::Result<String> {
    let addresses = env
        .call_method(link_props, "getLinkAddresses", "()Ljava/util/List;", &[])
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .l()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

    let size = env
        .call_method(&addresses, "size", "()I", &[])
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
        .i()
        .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

    for i in 0..size {
        let link_addr = env
            .call_method(&addresses, "get", "(I)Ljava/lang/Object;", &[JValue::Int(i)])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let addr = env
            .call_method(&link_addr, "getAddress", "()Ljava/net/InetAddress;", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;

        let host = env
            .call_method(&addr, "getHostAddress", "()Ljava/lang/String;", &[])
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .l()
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?;
        let s: String = env
            .get_string(&host.into())
            .map_err(|e| crate::Error::DeviceInfo(e.to_string()))?
            .into();

        // IPv4 addresses contain dots and no colons.
        if s.contains('.') && !s.contains(':') {
            return Ok(s);
        }
    }

    Ok("0.0.0.0".to_string())
}
