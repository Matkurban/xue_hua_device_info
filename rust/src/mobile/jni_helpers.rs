//! JNI helpers for Android platform adapters.

use jni::{
    Env, JavaVM,
    errors::Result as JniResult,
    jni_sig, jni_str,
    objects::{JObject, JString, JValue},
    sys::jint,
};

pub(crate) fn ensure_initialized() -> Result<(), String> {
    if crate::android_init::is_android_context_initialized() {
        Ok(())
    } else {
        Err("android context was not initialized".into())
    }
}

pub(crate) fn java_vm() -> Result<JavaVM, String> {
    ensure_initialized()?;
    let ctx = ndk_context::android_context();
    Ok(unsafe { JavaVM::from_raw(ctx.vm().cast()) })
}

pub(crate) fn with_env<F, T>(f: F) -> Result<T, String>
where
    F: FnOnce(&mut Env) -> JniResult<T>,
{
    let vm = java_vm()?;
    vm.attach_current_thread(|env| f(env))
        .map_err(|e| format!("JNI attach failed: {e}"))
}

pub(crate) fn application_context<'local>(env: &mut Env<'local>) -> JniResult<JObject<'local>> {
    let ctx_raw = ndk_context::android_context().context();
    Ok(unsafe { JObject::from_raw(env, ctx_raw.cast()) })
}

pub(crate) fn get_system_service<'local>(
    env: &mut Env<'local>,
    context: &JObject<'local>,
    service_name: &str,
) -> JniResult<JObject<'local>> {
    let name = env.new_string(service_name)?;
    env.call_method(
        context,
        jni_str!("getSystemService"),
        jni_sig!("(Ljava/lang/String;)Ljava/lang/Object;"),
        &[JValue::Object(&name)],
    )?
    .l()
}

pub(crate) fn settings_secure_get_string<'local>(
    env: &mut Env<'local>,
    context: &JObject<'local>,
    key: &str,
) -> JniResult<Option<String>> {
    let resolver = env
        .call_method(
            context,
            jni_str!("getContentResolver"),
            jni_sig!("()Landroid/content/ContentResolver;"),
            &[],
        )?
        .l()?;
    let key_obj = env.new_string(key)?;
    let result = env.call_static_method(
        jni_str!("android/provider/Settings$Secure"),
        jni_str!("getString"),
        jni_sig!("(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;"),
        &[JValue::Object(&resolver), JValue::Object(&key_obj)],
    )?;
    match result.l() {
        Ok(obj) if obj.is_null() => Ok(None),
        Ok(obj) => java_string_to_rust(env, obj).map(Some),
        Err(_) => Ok(None),
    }
}

pub(crate) fn settings_global_get_string<'local>(
    env: &mut Env<'local>,
    context: &JObject<'local>,
    key: &str,
) -> JniResult<Option<String>> {
    let resolver = env
        .call_method(
            context,
            jni_str!("getContentResolver"),
            jni_sig!("()Landroid/content/ContentResolver;"),
            &[],
        )?
        .l()?;
    let key_obj = env.new_string(key)?;
    let result = env.call_static_method(
        jni_str!("android/provider/Settings$Global"),
        jni_str!("getString"),
        jni_sig!("(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;"),
        &[JValue::Object(&resolver), JValue::Object(&key_obj)],
    )?;
    match result.l() {
        Ok(obj) if obj.is_null() => Ok(None),
        Ok(obj) => java_string_to_rust(env, obj).map(Some),
        Err(_) => Ok(None),
    }
}

pub(crate) fn intent_get_int_extra<'local>(
    env: &mut Env<'local>,
    intent: &JObject<'local>,
    key: &str,
    default: jint,
) -> JniResult<jint> {
    let key_obj = env.new_string(key)?;
    env.call_method(
        intent,
        jni_str!("getIntExtra"),
        jni_sig!("(Ljava/lang/String;I)I"),
        &[JValue::Object(&key_obj), JValue::Int(default)],
    )?
    .i()
}

pub(crate) fn java_string_to_rust<'local>(
    env: &Env<'local>,
    obj: JObject<'local>,
) -> JniResult<String> {
    let jstr = unsafe { JString::from_raw(env, obj.as_raw()) };
    Ok(jstr.mutf8_chars(env)?.to_string())
}

pub(crate) fn jstring_from_rust<'local>(
    env: &mut Env<'local>,
    value: &str,
) -> JniResult<JObject<'local>> {
    let s = env.new_string(value)?;
    Ok(s.into())
}
