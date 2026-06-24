## 0.7.3

### Added
- **Dual-backend API (`Sr25519Crypto`).** sr25519 operations can now run on either:
  - the **audited Rust backend** — FFI bindings to the [`schnorrkel`](https://docs.rs/schnorrkel)
    crate that [`sp_core::sr25519`](https://docs.rs/sp-core/latest/sp_core/sr25519/index.html) wraps,
    producing byte-identical keys, signatures, and verification results; or
  - the existing **pure-Dart backend** (unaudited).

  `Sr25519Crypto()` uses the Rust backend by default and transparently falls back to pure-Dart when
  the native library is not available. Pin a backend with `Sr25519Crypto.rust()` /
  `Sr25519Crypto.dart()`. The package remains **Flutter-free** (pure `dart:ffi`).
- **Precompiled binaries.** `dart run sr25519:setup` downloads a signed prebuilt native library for
  the current desktop platform (Linux/macOS/Windows on x64+arm64) and verifies it (Ed25519) before
  installing — no Rust toolchain needed. Built and published by
  `.github/workflows/release_sr25519.yml` on `sr25519-v<version>` tags.
- **Benchmark** (`benchmark/sr25519_benchmark.dart`) comparing the two backends across key
  generation, signing, and verification.
- Rust crate (`rust/`), build/sign tooling (`tool/build_rust.sh`, `tool/gen_key.dart`,
  `tool/sign_prebuilt.dart`), and `BUILD.md`.

The pure-Dart implementation and its public API are unchanged; this release is purely additive.

## 0.7.2

### Changed
- Code formatting improvements only - no functional changes
- All changes are cosmetic formatting improvements following Dart style guidelines
- Multi-line parameter formatting for better readability
- Trailing commas added throughout

## 0.7.1

 - Update dependencies

## 0.7.0

 - Bump polkadart version to 0.7.0

## 0.6.1
- Packages were bumped for new publish workflow

## 0.6.0
- All packages have been bumped to add web support

## 0.5.0
- Removes `json_schema2` from being a required dependency

## 0.4.1
- Fixes `UnmodifiableUint8ListView` missing on newer dart versions

## 0.4.0
- Bump dependency requirements

## 0.1.1
- Updates library description

## 0.1.0
- Initial version.
