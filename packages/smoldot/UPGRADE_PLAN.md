# smoldot upgrade plan — 0.18.0 → 1.2.0

**Goal:** upgrade the `smoldot` Dart package to the latest upstream `smoldot-light` (1.2.0),
verify everything builds and tests pass, keep this checklist current after each task.

## Background / findings

- Package was a snapshot of upstream **`smoldot-light 0.18.0`** (core `smoldot 0.20.0`),
  matching upstream commit `33d34fb8` dated **2025-10-20**.
- Latest upstream is **`1.2.0`** (published 2026-06-02), for both `smoldot-light` and core `smoldot`.
- The wrapper is thin: Rust touches only a few `smoldot-light` symbols; Dart is a generic JSON-RPC pump.
- **Only one source-level break**: `AddChainConfig` gained a required field
  `statement_protocol_config: Option<network_service::StatementProtocolConfig>`.
  Fix = add `statement_protocol_config: None`.
- All 17 legacy JSON-RPC methods used by `chain.dart` still exist upstream → Dart side unchanged.
- Hand-written `bindings.dart` matches the wrapper's own stable C header → unaffected.
- **Toolchain**: upstream workspace is now Rust **edition 2024** (needs rustc ≥ 1.85). Wrapper crate
  can stay edition 2021 but the build toolchain must be ≥ 1.85.

## Checklist

### Phase 0 — Prep
- [x] 0.1 Install Rust ≥ 1.85 (cargo/rustup) in the build environment — installed rustc/cargo **1.96.0**
- [x] 0.2 Install Dart SDK (to run the package tests) — Flutter-bundled Dart **3.12.0** at `~/flutter/bin`
- [x] 0.3 Add `rust/rust-toolchain.toml` pinning a known-good stable — pinned `1.96.0`

### Phase 1 — Bump & fix
- [x] 1.1 `rust/Cargo.toml`: `smoldot-light = "0.18"` → `"1.2"`
- [x] 1.2 `rust/src/lib.rs`: add `statement_protocol_config: None` to `AddChainConfig`
- [x] 1.3 Regenerate `rust/Cargo.lock` (smoldot-light 0.18→1.2.0, smoldot 0.20→1.2.0, wasmtime 36.0.6→36.0.11)
- [x] 1.4 `cargo build --release` succeeds (host target) — **0 errors**, 5 pre-existing dead-code warnings; produced `libsmoldot.so` (8.9M) + `libsmoldot.a` (30M); regenerated `native/smoldot.h` is byte-identical to committed (FFI surface unchanged)

### Phase 2 — Build & verify
- [x] 2.1 Built native lib (host) and placed at `native/linux/libsmoldot.so` (gitignored artifact); header regen verified byte-identical
- [x] 2.2 `dart pub get` (workspace root) — resolved OK
- [x] 2.3 Run the Dart test suite — **ALL GREEN (46/46)** against smoldot-light 1.2.0:
  `smoldot_test` 25/25, `ffi_basic_test` 2/2, `client_basic_test` 3/3 (incl. addChain Westend),
  `json_rpc_test` 7/7, `chain_info_test` 6/6 (synced Westend block 31674488, real hashes),
  `subscription_test` 3/3 (new heads + finalized heads + concurrent). Final sequential full-suite run confirming.
  Note: network suites need a per-test timeout > Westend warp-sync (~56s); subscription test's hardcoded
  internal 30s timeout was raised to 180s (pre-existing fragility, not a regression — see Phase 3.3).
- [x] 2.4 Connectivity smoke test (90s poll): **connected to 4 libp2p peers, warp sync completed (`isSyncing=false`), `chain_getFinalizedHead` returned a real block hash** → upgraded smoldot-light 1.2.0 validated end-to-end. (30s default test timeout < ~60s warp-sync was the only reason network tests failed initially.)

### Phase 3 — Housekeeping
- [x] 3.1 Fixed stale ffigen entry-point: `native/smoldot_light.h` → `native/smoldot.h`
- [x] 3.2 Bumped package version `0.1.2` → `0.1.3`; added CHANGELOG entry
- [x] 3.3 Raised `subscription_test` internal timeouts 30s → 180s to tolerate warp-sync latency (assertions unchanged)
- [x] 3.4 Added `rust/.gitignore` (`/target`) so the Rust build dir is never committed
- Note: `dart analyze` shows 4 pre-existing warnings in `analysis_options.yaml` (references to lint rules
  removed in newer Dart). Unrelated to smoldot; left as-is (out of scope). My edits add 0 analysis issues.

### Phase 4 — Optional enhancements (implemented on request)
- [x] 4.1 Exposed the statement-store config end-to-end:
  - Rust: new nullable `statement_config_json` FFI arg on `smoldot_add_chain`; parses
    `{maxSeenStatements, falsePositiveRate, affinityUpdateIntervalMs}`, validates (returns an error
    instead of asserting/aborting), builds `StatementProtocolConfig` with a random bloom seed sourced
    from the platform (stored `Arc<DefaultPlatform>` on the client wrapper). Struct in `ffi_types.rs`.
  - Dart: new `StatementStoreConfig` (defaults 65536 / 0.01 / 1000ms, mirroring upstream JS), wired
    through `AddChainConfig.statementStore` → `client.dart` → `bindings.dart` → FFI; exported from `smoldot.dart`.
  - Header regenerated (cbindgen) with the new param; matches hand-written bindings.
- [x] 4.2 Documented newly-reachable JSON-RPC methods: added constants to `SubstrateRpcMethods`
  (`chainHead_v1_*`, `transaction_v1_*`, `bitswap_v1_get`, `statement_*`) and a "JSON-RPC API" section
  in the README (incl. child-trie `chainHead_v1_storage` and statement-store usage example).

## Status: ✅ COMPLETE — latest smoldot (1.2.0) integrated + statement-store feature, builds clean, full suite green (51/51)

### Build coverage / honesty note
- Validated on **Linux x86_64 host only** (this environment): `cargo build --release` + full Dart suite vs live Westend.
- **Android / iOS not built here** — they need the Android NDK / a macOS host respectively. No platform-specific
  code changed (the sole source edit, `statement_protocol_config: None`, is platform-agnostic), so those targets
  build identically once their toolchains run `tool/build_android.sh` / `tool/build_ios.sh` in CI.

### Files changed
- `rust/Cargo.toml` (dep 0.18→1.2), `rust/Cargo.lock` (smoldot-light/smoldot 1.2.0, wasmtime 36.0.11)
- `rust/src/lib.rs` (statement_protocol_config wiring + `build_statement_config` + platform stored)
- `rust/src/ffi_types.rs` (new `StatementStoreConfigJson`)
- `rust/rust-toolchain.toml` (new, pin 1.96.0), `rust/.gitignore` (new, `/target`)
- `native/smoldot.h` (regenerated: new `statement_config_json` param)
- `lib/src/types.dart` (`StatementStoreConfig` + `AddChainConfig.statementStore`)
- `lib/src/bindings.dart` (FFI `addChain` + `statementConfigJson`), `lib/src/client.dart` (pass-through)
- `lib/src/json_rpc.dart` (new method constants), `lib/smoldot.dart` (export `StatementStoreConfig`)
- `pubspec.yaml` (version 0.1.3 + ffigen header fix), `CHANGELOG.md`, `README.md`
- `test/subscription_test.dart` (timeout robustness), `test/statement_store_test.dart` (new, 5 tests)
- `UPGRADE_PLAN.md` (this file)
- Not committed — changes staged on branch `chore/upgrade-smoldot-1.2.0`, ready for commit/PR on request.

## Progress log
- _(updated after each task)_
- Created branch `chore/upgrade-smoldot-1.2.0`; wrote this plan. Confirmed cargo/rustup/dart all absent in build env → Phase 0 install required first.
- Phase 0 complete: installed Rust 1.96.0 via rustup; found Dart 3.12.0 at `~/flutter/bin`; pinned toolchain via `rust/rust-toolchain.toml`.
- Phase 1.1–1.3 complete: bumped dep to `smoldot-light = "1.2"`, added `statement_protocol_config: None`, regenerated `Cargo.lock`. Release build kicked off (1.4).
- Phase 1.4 complete: `cargo build --release` → 0 errors; artifacts produced; `native/smoldot.h` regen byte-identical → FFI surface unchanged.
- Phase 2 (verify): offline suites green (`smoldot_test` 25/25, `ffi_basic` 2/2, `client_basic` 3/3). Connectivity smoke test connected to 4 peers + warp-synced + real finalized head. `json_rpc_test` now 7/7 with `--timeout=200s` (`chain_getFinalizedHead` completes at ~56s = warp-sync time). chain_info + subscription re-running with longer timeout.
- Phase 3 complete: fixed ffigen entry-point; bumped package to 0.1.3 + CHANGELOG; raised subscription-test timeouts; added rust/.gitignore.
- Phase 2 final: sequential full `dart test` run → **46/46 "All tests passed!", exit 0** against smoldot-light 1.2.0. chain_info synced Westend to block 31674488; subscription received new + finalized heads. Temp connectivity smoke script removed.
- DONE (core): latest smoldot integrated + verified end-to-end.
- Phase 4 implemented on request: statement-store config exposed through Dart/FFI (random bloom seed,
  validated), new JSON-RPC method constants + README docs. Rust rebuilt (0 errors), `.so` redeployed,
  header regenerated. Full sequential suite **51/51 "All tests passed!", exit 0** (incl. new statement_store_test:
  defaults/serialize/assert-guards + end-to-end addChain-with-statement-store on Westend). `dart analyze lib/` clean.
