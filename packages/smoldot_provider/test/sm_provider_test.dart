import 'dart:async';
import 'dart:collection';

import 'package:smoldot_provider/smoldot_provider.dart';
import 'package:test/test.dart';

/// Controllable [RawJsonRpcChain] for testing the provider without FFI.
class _FakeChain implements RawJsonRpcChain {
  final List<String> sent = [];
  final Queue<String> _buffer = Queue<String>();
  Completer<String>? _waiter;
  bool closed = false;

  /// Deliver a response/notification to the next (or a pending) pull.
  void deliver(String response) {
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) {
      _waiter = null;
      waiter.complete(response);
    } else {
      _buffer.add(response);
    }
  }

  @override
  void sendJsonRpc(String request) => sent.add(request);

  @override
  Future<String> nextJsonRpcResponse() {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeFirst());
    return (_waiter = Completer<String>()).future;
  }

  @override
  void close() {
    if (closed) return;
    closed = true;
    _waiter?.completeError(StateError('closed'));
    _waiter = null;
  }
}

void main() {
  group('getRawProvider', () {
    test('sends requests through to the chain', () {
      final chain = _FakeChain();
      final connection = getRawProvider(chain)((_) {});

      connection.send('{"id":1}');
      connection.send('{"id":2}');

      expect(chain.sent, ['{"id":1}', '{"id":2}']);
    });

    test('delivers chain responses to onMessage', () async {
      final chain = _FakeChain();
      final received = <String>[];
      getRawProvider(chain)(received.add);

      chain.deliver('{"id":1,"result":"a"}');
      chain.deliver('{"id":2,"result":"b"}');
      await Future<void>.delayed(Duration.zero);

      expect(received, ['{"id":1,"result":"a"}', '{"id":2,"result":"b"}']);
    });

    test('buffers sends until a pending chain resolves', () async {
      final chain = _FakeChain();
      final completer = Completer<RawJsonRpcChain>();
      final connection = getRawProvider(completer.future)((_) {});

      connection.send('{"id":1}');
      expect(
        chain.sent,
        isEmpty,
        reason: 'not flushed before the chain resolves',
      );

      completer.complete(chain);
      await Future<void>.delayed(Duration.zero);

      expect(chain.sent, ['{"id":1}']);
    });

    test('disconnect closes the chain and stops delivery', () async {
      final chain = _FakeChain();
      final received = <String>[];
      final connection = getRawProvider(chain)(received.add);

      connection.disconnect();
      expect(chain.closed, isTrue);

      chain.deliver('{"late":true}');
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty, reason: 'no delivery after disconnect');
    });

    test(
      'disconnect before a pending chain resolves closes it on arrival',
      () async {
        final chain = _FakeChain();
        final completer = Completer<RawJsonRpcChain>();
        final connection = getRawProvider(completer.future)((_) {});

        connection.disconnect();
        completer.complete(chain);
        await Future<void>.delayed(Duration.zero);

        expect(chain.closed, isTrue);
      },
    );
  });
}
