//! Build script: regenerate the C header (`../native/sr25519.h`) from the FFI exports via cbindgen.

use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let output_file = PathBuf::from(&crate_dir).join("../native/sr25519.h");

    let config = cbindgen::Config {
        language: cbindgen::Language::C,
        cpp_compat: true,
        include_guard: Some("SR25519_H".to_string()),
        export: cbindgen::ExportConfig {
            prefix: Some("Sr25519".to_string()),
            ..Default::default()
        },
        ..Default::default()
    };

    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_config(config)
        .generate()
        .expect("Unable to generate C bindings")
        .write_to_file(output_file);

    println!("cargo:rerun-if-changed=src/lib.rs");
}
