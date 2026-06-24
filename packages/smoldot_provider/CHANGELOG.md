## 0.1.0

- Initial release: `getSmProvider` turns a smoldot `Chain` into a standard
  string-based `JsonRpcProvider` (mirroring polkadot-api's
  `@polkadot-api/sm-provider`), plus the `JsonRpcProvider` / `JsonRpcConnection`
  types and a lower-level `getRawProvider` over a minimal `RawJsonRpcChain`.
