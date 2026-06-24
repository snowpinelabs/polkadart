# smoldot_provider

A light-client (smoldot) JSON-RPC provider for Dart — the Dart equivalent of
polkadot-api's smoldot provider ([`@polkadot-api/sm-provider`]).

`getSmProvider` turns a smoldot `Chain` into a standard, string-based
`JsonRpcProvider` (the same shape polkadot-api / substrate-connect use): you call
it with an `onMessage` callback and get back a connection you `send` raw JSON-RPC
strings to. **You run your own JSON-RPC client over it** — owning request ids and
subscription-id correlation — exactly as on the JS/TS path. Only the light-client
(smoldot) provider is supported; there is intentionally no WebSocket/other kind.

## Usage

```dart
import 'dart:convert';
import 'package:smoldot_provider/smoldot_provider.dart';

final client = SmoldotClient();
await client.initialize();

// getSmProvider accepts a Chain or a Future<Chain>, so pass addChain directly.
final JsonRpcProvider provider = getSmProvider(
  client.addChain(AddChainConfig(chainSpec: westendChainSpec)),
);

// Open a connection; every inbound JSON-RPC message arrives as a raw string.
final connection = provider((message) {
  final decoded = jsonDecode(message) as Map<String, dynamic>;
  // route by `id` (responses) or `params.subscription` (notifications)
});

connection.send('{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}');

// ... later
connection.disconnect(); // removes the chain from the smoldot client
```

Parachains pass `potentialRelayChains`; statement-store services enable
`AddChainConfig.statementStore`:

```dart
final relay = await client.addChain(AddChainConfig(chainSpec: relaySpec));
final provider = getSmProvider(
  client.addChain(AddChainConfig(
    chainSpec: assetHubSpec,
    potentialRelayChains: [relay.chainId],
    statementStore: StatementStoreConfig(),
  )),
);
```

## Interface

Mirrors polkadot-api's `@polkadot-api/json-rpc-provider`:

```dart
typedef JsonRpcProvider = JsonRpcConnection Function(
  void Function(String message) onMessage,
);

abstract interface class JsonRpcConnection {
  void send(String message);
  void disconnect();
}
```

`getRawProvider(FutureOr<RawJsonRpcChain>)` is the lower-level entry point: build
a provider over any minimal chain surface (`sendJsonRpc` / `nextJsonRpcResponse`
/ `close`) — used by tests and custom light-client sources.

## Develop

```bash
dart pub get
dart analyze
dart test               # unit tests (no native lib)
dart test --tags network  # integration vs a live chain (needs the smoldot native lib + network)
```

[`@polkadot-api/sm-provider`]: https://github.com/polkadot-api/polkadot-api/tree/main/packages/sm-provider
