## 1.2.1

- **`Chain` now exposes the raw JSON-RPC interface, matching the official smoldot JS bindings**:
  `sendJsonRpc(String)`, `nextJsonRpcResponse() -> Future<String>`, and
  `jsonRpcResponses -> Stream<String>`. The caller owns request ids and subscription
  correlation (run your own JSON-RPC client, as substrate-connect / polkadot-api do over the
  JS bindings). Removed the incomplete convenience layer that hid the raw interface and dropped
  subscription ids (`Chain.request`/`subscribe`/`unsubscribe`, the chain-info helpers, and
  `SmoldotClient.getAllChainInfo`); the `JsonRpcHandler` export is now `RawJsonRpc`.

## 1.2.0

- Realigned the package version to track the wrapped `smoldot-light` Rust crate version
  (previously `0.1.x`); from now on the package version mirrors the compatible `smoldot-light` release
- Upgraded `smoldot-light` from `0.18.0` to `1.2.0` (core `smoldot` `0.20.0` → `1.2.0`)
- Added the required `statement_protocol_config` field (new in smoldot-light 1.0.0) to the
  `add_chain` configuration; defaults to `None` (statement-store networking disabled), preserving
  previous behaviour
- Pinned the Rust build toolchain via `rust/rust-toolchain.toml` (smoldot-light 1.2.0 depends on
  Rust edition 2024, requiring rustc ≥ 1.85)
- Fixed the `ffigen` header entry-point to point at the generated `native/smoldot.h`
- Added optional `AddChainConfig.statementStore` (`StatementStoreConfig`) to enable Substrate's
  statement-store protocol per chain (new in smoldot-light 1.0.0); disabled by default
- Added `SubstrateRpcMethods` constants for the newer JSON-RPC API now available
  (`chainHead_v1_*`, `transaction_v1_*`, `bitswap_v1_get`, `statement_*`)
- Added `dart run smoldot:setup` (`bin/setup.dart`) to download a signed prebuilt native library
  for the current desktop platform from the GitHub Release, verify its Ed25519 signature, and
  install it into a per-user cache the loader finds automatically — no Rust toolchain required.
  Currently covers desktop Linux/macOS/Windows on x64+arm64; mobile prebuilts come later

## 0.1.2

- Code formatting and simplification of docker compose setup
- Updated dependencies: `ffi`, `meta`, `wasmtime`

## 0.1.1
- Upgraded sdk to ^3.8.0

## 0.1.0
- Initial code