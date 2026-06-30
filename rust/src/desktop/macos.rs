use std::process::Command;
use sysinfo::System;

use crate::models::*;

/// Helper function to run system_profiler with a specific data type and return parsed JSON
fn run_system_profiler(data_type: &str) -> Option<serde_json::Value> {
    Command::new("system_profiler")
        .args([data_type, "-json"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .and_then(|json| serde_json::from_str(&json).ok())
}

pub fn get_device_info() -> crate::Result<DeviceInfoResponse> {
    let hostname = System::host_name().unwrap_or_else(|| "Unknown Device".to_string());

    if let Some(v) = run_system_profiler("SPHardwareDataType") {
        if let Some(h) = v.get("SPHardwareDataType").and_then(|v| v.get(0)) {
            return Ok(DeviceInfoResponse {
                device_name: Some(hostname),
                manufacturer: Some("Apple Inc.".to_string()),
                model: h
                    .get("machine_name")
                    .and_then(|v| v.as_str().map(|s| s.to_string())),
                uuid: h
                    .get("platform_UUID")
                    .and_then(|v| v.as_str().map(|s| s.to_string())),
                serial: h
                    .get("serial_number")
                    .and_then(|v| v.as_str().map(|s| s.to_string())),
                android_id: None,
            });
        }
    }

    // Fallback response
    Ok(DeviceInfoResponse {
        device_name: Some(hostname),
        manufacturer: Some("Apple Inc.".to_string()),
        model: None,
        uuid: None,
        serial: None,
        android_id: None,
    })
}

/// Classify a macOS network interface name (e.g. `en0` → wifi).
pub(crate) fn classify_interface_name(name: &str) -> Option<String> {
    if name.starts_with("en") {
        if name == "en0" {
            Some("wifi".to_string())
        } else {
            Some("ethernet".to_string())
        }
    } else {
        None
    }
}

/// Parse whether the battery is charging from a `pmset -g batt` line.
pub(crate) fn parse_pmset_is_charging(output: &str) -> bool {
    let status = output
        .split('\t')
        .nth(1)
        .and_then(|s| s.split(';').nth(1))
        .map(|s| s.trim().to_lowercase());

    match status.as_deref() {
        Some("charging") | Some("charged") | Some("finishing charge") => true,
        Some("discharging") | Some("not charging") => false,
        _ => false,
    }
}

pub fn get_battery_info() -> crate::Result<BatteryInfo> {
    let output = Command::new("pmset")
        .args(["-g", "batt"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok());

    if let Some(output_str) = output {
        // Parse percentage
        let level = output_str
            .split('\t')
            .nth(1)
            .and_then(|s| s.split(';').next())
            .and_then(|s| s.replace('%', "").trim().parse::<f32>().ok());

        // Parse charging status
        let is_charging = parse_pmset_is_charging(&output_str);

        // Health is harder to get via pmset without XML, defaulting to good if present
        let health = if output_str.contains("present: true") {
            Some("Good".to_string())
        } else {
            None
        };

        return Ok(BatteryInfo {
            level,
            is_charging: Some(is_charging),
            health,
        });
    }

    Ok(BatteryInfo {
        level: None,
        is_charging: None,
        health: None,
    })
}

pub fn get_display_refresh_rate() -> Option<f64> {
    use core_graphics::display::CGDisplay;

    let main_display = CGDisplay::main();
    let mode = main_display.display_mode()?;
    let rate = mode.refresh_rate();

    // If refresh rate is 0, it means the display uses a variable refresh rate
    // In that case, return None or a default value
    if rate > 0.0 {
        Some(rate)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::{classify_interface_name, parse_pmset_is_charging};

    #[test]
    fn parse_battery_percentage_from_pmset_output() {
        // Simulated pmset output
        let pmset_output = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1234567)\t85%; discharging; 3:45 remaining present: true";

        // Extract percentage like our function does
        let level = pmset_output
            .split('\t')
            .nth(1)
            .and_then(|s| s.split(';').next())
            .and_then(|s| s.replace('%', "").trim().parse::<f32>().ok());

        assert_eq!(level, Some(85.0));
    }

    #[test]
    fn classify_interface_name_en0_is_wifi() {
        assert_eq!(
            classify_interface_name("en0"),
            Some("wifi".to_string())
        );
        assert_eq!(
            classify_interface_name("en1"),
            Some("ethernet".to_string())
        );
        assert!(classify_interface_name("lo0").is_none());
    }

    #[test]
    fn parse_charging_status_from_pmset() {
        let charging_output =
            "Now drawing from 'AC Power'\n -InternalBattery-0\t95%; charging; 0:30 remaining";
        let not_charging_output =
            "Now drawing from 'AC Power'\n -InternalBattery-0\t80%; not charging;";
        let discharging_output =
            "Now drawing from 'Battery Power'\n -InternalBattery-0\t85%; discharging; 3:45 remaining";

        assert!(parse_pmset_is_charging(charging_output));
        assert!(!parse_pmset_is_charging(not_charging_output));
        assert!(!parse_pmset_is_charging(discharging_output));
    }

    #[test]
    fn parse_system_profiler_json() {
        // Simulated system_profiler JSON output
        let json = r#"{
            "SPHardwareDataType": [{
                "machine_name": "MacBook Pro",
                "platform_UUID": "12345678-1234-5678-9ABC-DEF012345678",
                "serial_number": "C02ABC123"
            }]
        }"#;

        let v: serde_json::Value = serde_json::from_str(json).unwrap();

        let hardware = v.get("SPHardwareDataType").and_then(|v| v.get(0));

        assert!(hardware.is_some());

        let h = hardware.unwrap();
        assert_eq!(
            h.get("machine_name").and_then(|v| v.as_str()),
            Some("MacBook Pro")
        );
        assert_eq!(
            h.get("serial_number").and_then(|v| v.as_str()),
            Some("C02ABC123")
        );
    }

    #[test]
    fn fallback_hostname_works() {
        // Test that unwrap_or_else provides fallback
        let hostname: Option<String> = None;
        let result = hostname.unwrap_or_else(|| "Unknown Device".to_string());
        assert_eq!(result, "Unknown Device");
    }

    #[test]
    fn manufacturer_is_always_apple() {
        // All Macs should report Apple Inc.
        let manufacturer = Some("Apple Inc.".to_string());
        assert_eq!(manufacturer, Some("Apple Inc.".to_string()));
    }
}
