import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:smoldot/smoldot.dart';

/// Example demonstrating the smoldot package's **raw JSON-RPC interface**.
///
/// A [Chain] exposes the same surface as the official smoldot JS bindings:
/// `sendJsonRpc` / `nextJsonRpcResponse` / `jsonRpcResponses`. You own the
/// JSON-RPC envelope (ids, params) and subscription correlation — exactly like
/// substrate-connect / polkadot-api. This example shows the raw calls directly
/// plus a tiny inline request/subscription helper.
void main() async {
  final client = SmoldotClient(config: SmoldotConfig(maxLogLevel: 3));
  await client.initialize();

  final specFile = File('test/fixtures/westend.json');
  if (!specFile.existsSync()) {
    print(
      'Westend chain spec not found at test/fixtures/westend.json — download it with:\n'
      '  curl -o test/fixtures/westend.json '
      'https://raw.githubusercontent.com/smol-dot/smoldot/main/demo-chain-specs/westend.json',
    );
    await client.dispose();
    return;
  }

  final chain = await client.addChain(
    AddChainConfig(chainSpec: await specFile.readAsString()),
  );

  // --- Raw request/response: send a JSON-RPC string, read the next response.
  chain.sendJsonRpc(
    '{"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]}',
  );
  final raw = await chain.nextJsonRpcResponse();
  print('system_chain -> ${(jsonDecode(raw) as Map)['result']}');

  // --- A small JSON-RPC client over the raw stream (the canonical pattern).
  final rpc = _Rpc(chain);
  print('system_version -> ${await rpc.call('system_version')}');
  print('finalized head -> ${await rpc.call('chain_getFinalizedHead')}');

  // --- Subscription: follow the chain head and print the first few events.
  final (_, events) = await rpc.subscribe(
    'chain_subscribeNewHeads',
    const [],
    'chain_unsubscribeNewHeads',
  );
  var seen = 0;
  await for (final head in events) {
    print('new head -> ${(head as Map)['number']}');
    if (++seen >= 3) break;
  }

  await rpc.close();
  await client.dispose();
}

/// Minimal JSON-RPC client over a [Chain]'s raw interface (demo only).
class _Rpc {
  _Rpc(this._chain) {
    _loop();
  }

  final Chain _chain;
  int _nextId = 2;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final Map<String, StreamController<dynamic>> _subs = {};
  bool _closed = false;

  Future<dynamic> call(String method, [List<dynamic> params = const []]) {
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
    return completer.future.then((m) => m['result']);
  }

  Future<(String, Stream<dynamic>)> subscribe(
    String method,
    List<dynamic> params,
    String unsubscribeMethod,
  ) async {
    final id = (await call(method, params)).toString();
    final controller = StreamController<dynamic>(
      onCancel: () {
        _subs.remove(id);
        if (!_closed) call(unsubscribeMethod, [id]).ignore();
      },
    );
    _subs[id] = controller;
    return (id, controller.stream);
  }

  Future<void> _loop() async {
    try {
      await for (final raw in _chain.jsonRpcResponses) {
        if (_closed) break;
        final message = jsonDecode(raw) as Map<String, dynamic>;
        final id = message['id'];
        if (id != null) {
          _pending.remove((id as num).toInt())?.complete(message);
        } else if (message['params'] is Map<String, dynamic>) {
          final params = message['params'] as Map<String, dynamic>;
          _subs[params['subscription']?.toString()]?.add(params['result']);
        }
      }
    } catch (_) {
      // stream closed
    }
  }

  Future<void> close() async {
    _closed = true;
    for (final c in _subs.values) {
      await c.close();
    }
    _subs.clear();
  }
}
