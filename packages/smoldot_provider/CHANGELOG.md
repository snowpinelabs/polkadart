## 1.2.1

- Initial release. Versioned to track the `smoldot` package it depends on
  (the matching `smoldot` release exposes the raw JSON-RPC `Chain` interface
  this provider is built on).
- `getSmProvider` turns a smoldot `Chain` into a standard string-based
  `JsonRpcProvider` (mirroring polkadot-api's `@polkadot-api/sm-provider`),
  plus the `JsonRpcProvider` / `JsonRpcConnection` types and a lower-level
  `getRawProvider` over a minimal `RawJsonRpcChain`.
