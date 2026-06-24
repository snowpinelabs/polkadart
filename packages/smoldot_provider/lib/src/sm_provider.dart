import 'dart:async';

import 'package:smoldot/smoldot.dart';

import 'json_rpc_provider.dart';

/// The minimal smoldot-chain surface a [JsonRpcProvider] needs: send request
/// strings, pull response/notification strings, and release the chain.
///
/// A real smoldot [Chain] is adapted to this by [getSmProvider]; tests and
/// custom light-client sources can implement it directly and use [getRawProvider].
abstract interface class RawJsonRpcChain {
  /// Send a raw JSON-RPC request string.
  void sendJsonRpc(String request);

  /// Pull the next JSON-RPC response/notification string (called sequentially).
  Future<String> nextJsonRpcResponse();

  /// Release the chain (stop the response pump; free native resources where
  /// the source owns them).
  void close();
}

/// Wrap a smoldot [Chain] as a [JsonRpcProvider], mirroring polkadot-api's
/// `getSmProvider` (`@polkadot-api/sm-provider`).
///
/// Accepts a `Chain` or a `Future<Chain>` so you can pass the result of
/// `client.addChain(...)` directly. Messages sent before the chain resolves are
/// buffered. `disconnect()` removes the chain from its smoldot client.
///
/// ```dart
/// final client = SmoldotClient();
/// await client.initialize();
/// final provider = getSmProvider(client.addChain(AddChainConfig(chainSpec: spec)));
///
/// final connection = provider((message) {
///   // raw JSON-RPC response/notification string
/// });
/// connection.send('{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}');
/// // ... later: connection.disconnect();
/// ```
JsonRpcProvider getSmProvider(FutureOr<Chain> chain) {
  final FutureOr<RawJsonRpcChain> raw = chain is Future<Chain>
      ? chain.then(_SmoldotChain.new)
      : _SmoldotChain(chain);
  return getRawProvider(raw);
}

/// Lower-level [getSmProvider]: build a [JsonRpcProvider] over any
/// [RawJsonRpcChain] (a smoldot chain adapter, a fake, or another light client).
JsonRpcProvider getRawProvider(FutureOr<RawJsonRpcChain> chain) =>
    (onMessage) => _Connection(chain, onMessage);

/// Adapts a real smoldot [Chain] to [RawJsonRpcChain]. `close()` removes the
/// chain from its [SmoldotClient] (freeing native resources); if the owning
/// object is not a client, it just disposes the chain's response pump.
class _SmoldotChain implements RawJsonRpcChain {
  _SmoldotChain(this._chain);

  final Chain _chain;

  @override
  void sendJsonRpc(String request) => _chain.sendJsonRpc(request);

  @override
  Future<String> nextJsonRpcResponse() => _chain.nextJsonRpcResponse();

  @override
  void close() {
    final client = _chain.client;
    if (client is SmoldotClient) {
      client.removeChain(_chain.chainId).ignore();
    } else {
      _chain.dispose();
    }
  }
}

class _Connection implements JsonRpcConnection {
  _Connection(FutureOr<RawJsonRpcChain> chain, this._onMessage) {
    if (chain is Future<RawJsonRpcChain>) {
      chain.then(_onReady, onError: (Object _) => _stopped = true);
    } else {
      _onReady(chain);
    }
  }

  final void Function(String message) _onMessage;
  RawJsonRpcChain? _chain;
  final List<String> _buffered = [];
  bool _stopped = false;

  void _onReady(RawJsonRpcChain chain) {
    if (_stopped) {
      chain.close();
      return;
    }
    _chain = chain;
    for (final message in _buffered) {
      chain.sendJsonRpc(message);
    }
    _buffered.clear();
    _readLoop(chain);
  }

  Future<void> _readLoop(RawJsonRpcChain chain) async {
    while (!_stopped) {
      final String response;
      try {
        response = await chain.nextJsonRpcResponse();
      } catch (_) {
        break; // chain closed or errored
      }
      if (_stopped) break;
      _onMessage(response);
    }
  }

  @override
  void send(String message) {
    if (_stopped) return;
    final chain = _chain;
    if (chain != null) {
      chain.sendJsonRpc(message);
    } else {
      _buffered.add(message);
    }
  }

  @override
  void disconnect() {
    if (_stopped) return;
    _stopped = true;
    _buffered.clear();
    _chain?.close();
  }
}
