/// A Dart wrapper for smoldot-light, providing a lightweight Polkadot/Substrate client
///
/// This library provides idiomatic Dart bindings for the smoldot-light Rust library,
/// enabling lightweight blockchain client functionality without requiring a full node.
///
/// ## Features
///
/// - **Lightweight**: No need for a full node, runs entirely in-process
/// - **Multi-chain**: Support for multiple chains simultaneously (relay + parachains)
/// - **Async/Await**: Idiomatic Dart async APIs for all operations
/// - **JSON-RPC**: Full JSON-RPC support with subscriptions
/// - **Type-safe**: Comprehensive type definitions and error handling
/// - **Cross-platform**: Works on Android, iOS, macOS, Linux, and Windows
///
/// ## Usage
///
/// The `Chain` exposes the **raw JSON-RPC interface** — the exact shape of the
/// official smoldot JS bindings (`sendJsonRpc` / `nextJsonRpcResponse` /
/// `jsonRpcResponses`). The caller owns request ids and subscription
/// correlation; run a JSON-RPC client on top (as substrate-connect /
/// polkadot-api do) for request/response and subscription helpers.
///
/// ```dart
/// import 'dart:convert';
/// import 'package:smoldot/smoldot.dart';
///
/// void main() async {
///   // Create and initialize the client
///   final client = SmoldotClient(
///     config: SmoldotConfig(
///       maxLogLevel: 3,
///       maxChains: 8,
///     ),
///   );
///
///   await client.initialize();
///
///   // Add a chain
///   final chain = await client.addChain(
///     AddChainConfig(
///       chainSpec: polkadotChainSpec,
///     ),
///   );
///
///   // Send a JSON-RPC request with your own id, then read the response.
///   chain.sendJsonRpc(
///     '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}',
///   );
///   final response = jsonDecode(await chain.nextJsonRpcResponse());
///   print('Connected to: ${response['result']}');
///
///   // Subscribe by reading the continuous response/notification stream.
///   chain.sendJsonRpc(
///     '{"jsonrpc":"2.0","id":2,"method":"chainHead_v1_follow","params":[false]}',
///   );
///   await for (final raw in chain.jsonRpcResponses) {
///     print('chainHead event: $raw');
///   }
///
///   // Clean up
///   await client.dispose();
/// }
/// ```
///
/// ## Adding Multiple Chains
///
/// ```dart
/// // Add Polkadot relay chain
/// final polkadot = await client.addChain(
///   AddChainConfig(chainSpec: polkadotSpec),
/// );
///
/// // Add a parachain
/// final statemint = await client.addChain(
///   AddChainConfig(
///     chainSpec: statemintSpec,
///     potentialRelayChains: [polkadot.chainId],
///   ),
/// );
/// ```
///
/// ## Logging
///
/// ```dart
/// // Listen to logs
/// client.logs.listen((log) {
///   print('${log.level}: ${log.message}');
/// });
///
/// // Change log level
/// client.setLogLevel(LogLevel.debug);
/// ```
///
/// ## Persistence
///
/// ```dart
/// // Restore from a previously saved database snapshot.
/// final chain = await client.addChain(
///   AddChainConfig(
///     chainSpec: spec,
///     databaseContent: await loadFromFile(),
///   ),
/// );
/// ```
///
/// ## Error Handling
///
/// ```dart
/// try {
///   chain.sendJsonRpc(
///     '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}',
///   );
///   print(await chain.nextJsonRpcResponse());
/// } on SmoldotException catch (e) {
///   print('Smoldot error: ${e.message}');
/// }
/// ```
library smoldot;

export 'src/chain.dart' show Chain;
export 'src/client.dart' show SmoldotClient;
export 'src/json_rpc.dart' show RawJsonRpc, SubstrateRpcMethods;
export 'src/platform.dart' show SmoldotPlatform;
export 'src/types.dart'
    show
        SmoldotConfig,
        AddChainConfig,
        StatementStoreConfig,
        JsonRpcResponse,
        JsonRpcError,
        ChainStatus,
        ChainInfo,
        LogLevel,
        LogMessage,
        SmoldotException,
        SmoldotFfiException,
        ChainException,
        JsonRpcException;
