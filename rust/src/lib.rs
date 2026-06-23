pub mod api;
pub mod error;
pub mod models;

pub use error::{Error, Result};

#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub mod desktop;

#[cfg(any(target_os = "android", target_os = "ios"))]
pub mod mobile;

mod frb_generated;
