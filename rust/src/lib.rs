pub mod api;
pub mod error;
pub mod models;

pub use error::{Error, Result};

#[cfg(target_os = "android")]
mod android_init;

#[cfg(any(target_os = "ios", target_os = "android"))]
pub mod mobile;

#[cfg(not(any(target_os = "ios", target_os = "android")))]
pub mod desktop;

mod frb_generated;
mod platform;
