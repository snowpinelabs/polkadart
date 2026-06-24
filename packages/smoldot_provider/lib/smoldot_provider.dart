/// A light-client (smoldot) JSON-RPC provider for Dart.
///
/// Mirrors polkadot-api's smoldot provider (`@polkadot-api/sm-provider`):
/// [getSmProvider] turns a smoldot [Chain] into a standard string-based
/// [JsonRpcProvider]. The caller runs its own JSON-RPC client over it (owning
/// request ids and subscription correlation), exactly as on the JS/TS path.
///
/// ```dart
/// import 'package:smoldot_provider/smoldot_provider.dart';
///
/// final client = SmoldotClient();
/// await client.initialize();
/// final provider = getSmProvider(
///   client.addChain(AddChainConfig(chainSpec: chainSpec)),
/// );
/// ```
library;

export 'src/json_rpc_provider.dart';
export 'src/sm_provider.dart'
    show RawJsonRpcChain, getRawProvider, getSmProvider;

// Re-export the smoldot pieces a provider consumer needs, so a single import of
// `package:smoldot_provider/smoldot_provider.dart` is enough.
export 'package:smoldot/smoldot.dart'
    show
        AddChainConfig,
        Chain,
        SmoldotClient,
        SmoldotConfig,
        StatementStoreConfig;
