# Building the sr25519 Rust backend

The `sr25519` package has two backends:

- **pure-Dart** — always works, no toolchain, no native library. Unaudited.
- **Rust (default)** — FFI bindings to the audited [`schnorrkel`](https://docs.rs/schnorrkel) crate
  (the same implementation [`sp_core::sr25519`](https://docs.rs/sp-core/latest/sp_core/sr25519/index.html)
  wraps). Needs the native library described here.

Consumers normally **do not build anything** — they run `dart run sr25519:setup` to download a signed
prebuilt. This document is for building the native library from source (development, CI, or an
unsupported platform).

## Prerequisites

- **Rust** (pinned by `rust/rust-toolchain.toml`; install from <https://rustup.rs/>)
- **Dart SDK** 3.8+

## Desktop (Linux, macOS, Windows)

```bash
cd packages/sr25519
./tool/build_rust.sh
```

This compiles the release library and copies it into `native/<platform>/`:

- **Linux**: `native/linux/libsr25519.so`
- **macOS**: `native/macos/libsr25519.dylib` (universal: x86_64 + arm64)
- **Windows**: `native/windows/sr25519.dll`

The C header `native/sr25519.h` is regenerated from the Rust source on every `cargo build`
(`rust/build.rs` + cbindgen).

## Manual / cross-compilation

```bash
cd packages/sr25519/rust

# Native release build
cargo build --release            # -> target/release/libsr25519.{so,dylib,dll}

# A specific target
rustup target add aarch64-apple-darwin
cargo build --release --target aarch64-apple-darwin
```

For a portable Linux glibc floor and arm64 cross-builds, CI uses
[`cargo-zigbuild`](https://github.com/rust-cross/cargo-zigbuild) (see
`.github/workflows/release_sr25519.yml`).

### Android / iOS

The Rust crate builds `cdylib` **and** `staticlib`, so it can also be embedded into mobile host apps.
Add the relevant `rustup target`s (see `rust/.cargo/config.toml` for the NDK/clang linkers) and build
per target. Mobile libraries are embedded by the host app, not downloaded by `sr25519:setup`.

## How the library is found at runtime

`lib/src/backend/platform.dart` searches, in order:

1. the per-user cache populated by `dart run sr25519:setup`;
2. `rust/target/{release,debug}/` (local `cargo build`);
3. conventional locations next to the package (`native/<platform>/`, etc.);
4. the system library path.

If none resolve, `Sr25519Crypto()` silently uses the pure-Dart backend. Use `Sr25519Crypto.rust()`
to require the native backend (it throws a helpful error if unavailable).

## Releasing signed prebuilts

`.github/workflows/release_sr25519.yml` runs on a `sr25519-v<version>` tag: it builds the desktop
targets, signs each with Ed25519 (`tool/sign_prebuilt.dart`, key in `SR25519_SIGNING_KEY`), and
uploads `sr25519-<target>.<ext>` + `.sig` to the release. `dart run sr25519:setup` then downloads and
verifies them against `kPrebuiltPublicKeyHex` (`lib/src/backend/prebuilt.dart`).

Rotate the signing key with `dart run tool/gen_key.dart` (paste the public hex into `prebuilt.dart`,
store the private hex as the `SR25519_SIGNING_KEY` repository secret), and bump the package version.

## Release profile

`rust/Cargo.toml` optimises for **throughput** (`opt-level = 3`, `lto = true`, `codegen-units = 1`,
`strip = true`, `panic = "abort"`). The library is ~0.4 MB.
