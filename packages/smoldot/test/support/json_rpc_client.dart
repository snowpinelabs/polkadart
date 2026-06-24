import 'dart:async';
import 'dart:convert';

import 'package:smoldot/smoldot.dart';

/// Minimal JSON-RPC client over a smoldot [Chain]'s raw interface.
///
/// Mirrors how substrate-connect / polkadot-api consume smoldot: a single
/// read-loop over [Chain.jsonRpcResponses] demultiplexes responses by request
/// `id` and notifications by `params.subscription`. Test/example support only —
/// real consumers should bring their own JSON-RPC client.
class JsonRpcClient {
  JsonRpcClient(this._chain) {
    _loop();
  }

  final Chain _chain;
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final Map<String, StreamController<dynamic>> _subscriptions = {};
  bool _closed = false;

  /// Send a JSON-RPC request and await its `result` (throws on a JSON-RPC error).
  Future<dynamic> call(String method, [List<dynamic> params = const []]) async {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _chain.sendJsonRpc(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    final message = await completer.future;
    final error = message['error'];
    if (error != null) {
      throw StateError('JSON-RPC error for $method: $error');
    }
    return message['result'];
  }

  /// Start a subscription. Returns its id and a stream of notification payloads.
  /// Cancelling the stream sends [unsubscribeMethod] with the subscription id.
  Future<(String, Stream<dynamic>)> subscribe(
    String method,
    List<dynamic> params,
    String unsubscribeMethod,
  ) async {
    final subscriptionId = (await call(method, params)).toString();
    final controller = StreamController<dynamic>(
      onCancel: () {
        _subscriptions.remove(subscriptionId);
        if (!_closed) {
          call(unsubscribeMethod, [subscriptionId]).ignore();
        }
      },
    );
    _subscriptions[subscriptionId] = controller;
    return (subscriptionId, controller.stream);
  }

  Future<void> _loop() async {
    try {
      await for (final raw in _chain.jsonRpcResponses) {
        if (_closed) break;
        final message = jsonDecode(raw) as Map<String, dynamic>;
        final id = message['id'];
        if (id != null) {
          _pending.remove((id as num).toInt())?.complete(message);
          continue;
        }
        // Notification: { method, params: { subscription, result } }.
        final params = message['params'];
        if (params is Map<String, dynamic>) {
          final subscription = params['subscription']?.toString();
          if (subscription != null) {
            _subscriptions[subscription]?.add(params['result']);
          }
        }
      }
    } catch (_) {
      // Stream closed (chain disposed).
    }
  }

  /// Stop consuming and close any open subscription controllers.
  Future<void> close() async {
    _closed = true;
    for (final controller in _subscriptions.values) {
      await controller.close();
    }
    _subscriptions.clear();
  }
}
