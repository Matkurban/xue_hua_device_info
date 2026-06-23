pub mod api;
pub mod error;
pub mod models;

pub use error::{Error, Result};

#[cfg(not(target_os = "ios"))]
pub mod desktop;

#[cfg(target_os = "ios")]
pub mod mobile;

mod frb_generated;
