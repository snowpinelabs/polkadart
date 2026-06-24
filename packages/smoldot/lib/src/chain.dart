import 'dart:async';
import 'bindings.dart';
import 'json_rpc.dart';
import 'types.dart';

/// Represents a blockchain chain managed by smoldot.
///
/// A [Chain] exposes the **raw JSON-RPC interface** — the exact shape of the
/// official smoldot JS bindings' `Chain` (`sendJsonRpc` / `nextJsonRpcResponse`
/// / `jsonRpcResponses`). It does not correlate requests, responses, or
/// subscriptions for you: send JSON-RPC request strings with your own ids and
/// read response/notification strings back. Run a JSON-RPC client on top (as
/// substrate-connect / polkadot-api do) if you want request/response and
/// subscription helpers.
class Chain {
  /// Chain identifier (handle from Rust)
  final int chainId;

  /// Parent client instance (kept as reference)
  final Object client;

  /// FFI bindings
  final SmoldotBindings bindings;

  /// Native client handle (u64 from Rust)
  final int clientHandle;

  /// Raw JSON-RPC pump for this chain
  late final RawJsonRpc _jsonRpc;

  /// Whether the chain has been disposed
  bool _isDisposed = false;

  /// Creates a new Chain instance.
  ///
  /// This is typically called internally by [SmoldotClient.addChain].
  Chain({
    required this.chainId,
    required this.client,
    required this.bindings,
    required this.clientHandle,
  }) {
    _jsonRpc = RawJsonRpc(chainId: chainId, bindings: bindings);
  }

  /// Whether this chain has been disposed
  bool get isDisposed => _isDisposed;

  /// Send a raw JSON-RPC request string to the chain.
  ///
  /// The caller owns the JSON-RPC envelope (`jsonrpc`, `id`, `method`, `params`)
  /// and any subscription-id correlation. Responses and notifications are read
  /// back via [nextJsonRpcResponse] / [jsonRpcResponses].
  ///
  /// Matches smoldot JS `Chain.sendJsonRpc`.
  ///
  /// Example:
  /// ```dart
  /// chain.sendJsonRpc(
  ///   '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}',
  /// );
  /// final response = await chain.nextJsonRpcResponse();
  /// ```
  void sendJsonRpc(String rpc) {
    _ensureNotDisposed();
    _jsonRpc.send(rpc);
  }

  /// Pull the next JSON-RPC response or notification as a raw JSON string.
  ///
  /// Pulls one element from the chain's response buffer (matches smoldot JS
  /// `Chain.nextJsonRpcResponse`). Call sequentially — await each result before
  /// requesting the next. Prefer [jsonRpcResponses] to consume a continuous
  /// stream.
  Future<String> nextJsonRpcResponse() {
    _ensureNotDisposed();
    return _jsonRpc.next();
  }

  /// A stream of raw JSON-RPC response/notification strings (sugar over repeated
  /// [nextJsonRpcResponse]). Matches smoldot JS `Chain.jsonRpcResponses`.
  ///
  /// Single-subscription: listen once. Use either this or [nextJsonRpcResponse],
  /// not both concurrently.
  ///
  /// Example:
  /// ```dart
  /// chain.sendJsonRpc(
  ///   '{"jsonrpc":"2.0","id":1,"method":"chainHead_v1_follow","params":[false]}',
  /// );
  /// await for (final raw in chain.jsonRpcResponses) {
  ///   final message = jsonDecode(raw) as Map<String, dynamic>;
  ///   // ... route by `id` (responses) or `params.subscription` (notifications)
  /// }
  /// ```
  Stream<String> get jsonRpcResponses {
    _ensureNotDisposed();
    return _jsonRpc.responses;
  }

  /// Dispose of this chain and free resources.
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _jsonRpc.dispose();
    _isDisposed = true;
  }

  /// Ensure the chain is not disposed
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw SmoldotException('Chain $chainId has been disposed');
    }
  }

  @override
  String toString() => 'Chain(chainId: $chainId, isDisposed: $_isDisposed)';
}
