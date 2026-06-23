## 0.1.3

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

## 0.1.2

- Code formatting and simplification of docker compose setup
- Updated dependencies: `ffi`, `meta`, `wasmtime`

## 0.1.1
- Upgraded sdk to ^3.8.0

## 0.1.0
- Initial code