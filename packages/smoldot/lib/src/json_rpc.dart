import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'bindings.dart';
import 'types.dart';

/// Global registry mapping a unique callback id to the completer awaiting the
/// next JSON-RPC response string for that pull.
final Map<int, Completer<String>> _responseRegistry = {};

/// Process-wide monotonic callback id so concurrent chains never collide.
int _nextCallbackId = 0;

/// Invoked from Rust when a JSON-RPC response/notification is ready for a
/// pending [RawJsonRpc.next] pull.
void _onJsonRpcResponse(int callbackId, int result, Pointer<Utf8> error) {
  final completer = _responseRegistry.remove(callbackId);
  if (completer == null) {
    return;
  }
  if (error != nullptr) {
    completer.completeError(
      JsonRpcException('JSON-RPC error: ${error.toDartString()}'),
    );
  } else {
    completer.complete(Pointer<Utf8>.fromAddress(result).toDartString());
  }
}

/// Raw JSON-RPC pump over smoldot's FFI for a single chain.
///
/// Mirrors the official smoldot **JS** `Chain` interface: you send raw JSON-RPC
/// request strings and pull raw response/notification strings. There is **no**
/// request/subscription correlation here — the caller owns request ids,
/// subscription-id correlation, and framing (i.e. runs its own JSON-RPC client),
/// exactly like substrate-connect / polkadot-api do over the JS bindings.
class RawJsonRpc {
  RawJsonRpc({required this.chainId, required this.bindings}) {
    _nativeCallable = NativeCallable<DartCallbackNative>.listener(
      _onJsonRpcResponse,
    );
    _nativeCallback = _nativeCallable.nativeFunction;
  }

  /// Chain handle this pump talks to.
  final int chainId;

  /// FFI bindings.
  final SmoldotBindings bindings;

  late final NativeCallable<DartCallbackNative> _nativeCallable;
  late final Pointer<NativeFunction<DartCallbackNative>> _nativeCallback;

  /// Callback ids of in-flight [next] pulls, so [dispose] can settle them.
  final Set<int> _pending = {};

  Stream<String>? _responses;
  bool _disposed = false;

  /// Send a raw JSON-RPC request string to the chain.
  void send(String rpc) {
    _ensureNotDisposed();
    bindings.sendJsonRpcRequest(chainId, rpc);
  }

  /// Pull the next JSON-RPC response or notification as a raw JSON string.
  ///
  /// Call sequentially: await each result before requesting the next one (the
  /// same contract as the JS `nextJsonRpcResponse`).
  Future<String> next() {
    _ensureNotDisposed();
    final callbackId = _nextCallbackId++;
    final completer = Completer<String>();
    _responseRegistry[callbackId] = completer;
    _pending.add(callbackId);
    bindings.nextJsonRpcResponse(
      chainHandle: chainId,
      callbackId: callbackId,
      callback: _nativeCallback,
    );
    return completer.future.whenComplete(() => _pending.remove(callbackId));
  }

  /// A single-subscription stream of raw response/notification strings — sugar
  /// over repeated [next]. Use either this or [next], not both concurrently.
  Stream<String> get responses => _responses ??= _pump();

  Stream<String> _pump() async* {
    while (!_disposed) {
      yield await next();
    }
  }

  /// Release the native callback and settle any in-flight pulls.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final callbackId in _pending.toList()) {
      _responseRegistry
          .remove(callbackId)
          ?.completeError(
            SmoldotException('Chain $chainId JSON-RPC handler disposed'),
          );
    }
    _pending.clear();
    _nativeCallable.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw SmoldotException('Chain $chainId JSON-RPC handler disposed');
    }
  }
}

/// Predefined Substrate JSON-RPC method names (convenience constants for use
/// with the raw [RawJsonRpc] / `Chain.sendJsonRpc` interface).
class SubstrateRpcMethods {
  /// Get the name of the blockchain
  static const systemChain = 'system_chain';

  /// Get the version of the node
  static const systemVersion = 'system_version';

  /// Get the name of the node
  static const systemName = 'system_name';

  /// Get properties of the blockchain
  static const systemProperties = 'system_properties';

  /// Get the node's health status
  static const systemHealth = 'system_health';

  /// Get the genesis hash
  static const chainGetBlockHash = 'chain_getBlockHash';

  /// Get the latest finalized block hash
  static const chainGetFinalizedHead = 'chain_getFinalizedHead';

  /// Get a block by hash
  static const chainGetBlock = 'chain_getBlock';

  /// Subscribe to new block headers
  static const chainSubscribeNewHeads = 'chain_subscribeNewHeads';

  /// Subscribe to finalized block headers
  static const chainSubscribeFinalizedHeads = 'chain_subscribeFinalizedHeads';

  /// Unsubscribe from block header updates
  static const chainUnsubscribeNewHeads = 'chain_unsubscribeNewHeads';

  /// Unsubscribe from finalized block header updates
  static const chainUnsubscribeFinalizedHeads =
      'chain_unsubscribeFinalizedHeads';

  /// Get runtime metadata
  static const stateGetMetadata = 'state_getMetadata';

  /// Get runtime version
  static const stateGetRuntimeVersion = 'state_getRuntimeVersion';

  /// Query storage at a block
  static const stateGetStorage = 'state_getStorage';

  /// Call a runtime method
  static const stateCall = 'state_call';

  /// Submit an extrinsic
  static const authorSubmitExtrinsic = 'author_submitExtrinsic';

  /// Subscribe to extrinsic statuses
  static const authorSubmitAndWatchExtrinsic = 'author_submitAndWatchExtrinsic';

  /// Unsubscribe from extrinsic status updates
  static const authorUnwatchExtrinsic = 'author_unwatchExtrinsic';

  // ===== New JSON-RPC API (smoldot-light >= 1.0) =====
  // Reachable through the raw `Chain.sendJsonRpc` / [RawJsonRpc.send] interface;
  // the constants are provided for convenience and discoverability.

  /// chainHead v1: follow the head of the chain (JSON-RPC v2 / "new" API).
  static const chainHeadV1Follow = 'chainHead_v1_follow';

  /// chainHead v1: read storage entries at a followed block. Since smoldot 1.2.0 this can also
  /// read the default child trie (e.g. contract storage) via the optional `childTrie` parameter.
  static const chainHeadV1Storage = 'chainHead_v1_storage';

  /// chainHead v1: call a runtime entry point at a followed block.
  static const chainHeadV1Call = 'chainHead_v1_call';

  /// chainHead v1: stop a previously started operation.
  static const chainHeadV1StopOperation = 'chainHead_v1_stopOperation';

  /// chainHead v1: stop following the chain.
  static const chainHeadV1Unfollow = 'chainHead_v1_unfollow';

  /// transaction v1: submit and watch a transaction (JSON-RPC v2 / "new" API).
  static const transactionV1Broadcast = 'transaction_v1_broadcast';

  /// transactionWatch v1: submit and watch a transaction's progress.
  static const transactionWatchV1SubmitAndWatch =
      'transactionWatch_v1_submitAndWatch';

  /// Bitswap: fetch an IPFS block by CID over the chain's p2p network (smoldot >= 3.1.0).
  static const bitswapV1Get = 'bitswap_v1_get';

  // ----- Statement store (requires AddChainConfig.statementStore to be enabled) -----

  /// Submit a statement to the statement store.
  static const statementSubmit = 'statement_submit';

  /// Subscribe to statements matching a set of topics.
  static const statementSubscribeStatement = 'statement_subscribeStatement';

  /// Unsubscribe from a statement subscription.
  static const statementUnsubscribeStatement = 'statement_unsubscribeStatement';
}
