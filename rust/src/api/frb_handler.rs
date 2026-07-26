//! Standard [`FLUTTER_RUST_BRIDGE_HANDLER`] for cross-platform execution.

use flutter_rust_bridge::for_generated::{
    lazy_static, SimpleThreadPool, FLUTTER_RUST_BRIDGE_RUNTIME_VERSION,
};
use flutter_rust_bridge::DefaultHandler;

use crate::frb_generated::FLUTTER_RUST_BRIDGE_CODEGEN_VERSION;

type FrbHandler = DefaultHandler<SimpleThreadPool>;

fn build_handler() -> FrbHandler {
    assert_eq!(
        FLUTTER_RUST_BRIDGE_CODEGEN_VERSION,
        FLUTTER_RUST_BRIDGE_RUNTIME_VERSION,
        "Please ensure flutter_rust_bridge's codegen ({}) and runtime ({}) versions are the same",
        FLUTTER_RUST_BRIDGE_CODEGEN_VERSION,
        FLUTTER_RUST_BRIDGE_RUNTIME_VERSION,
    );

    DefaultHandler::new_simple(Default::default())
}

lazy_static! {
    /// Process-wide FRB handler.
    pub static ref FLUTTER_RUST_BRIDGE_HANDLER: FrbHandler = build_handler();
}

