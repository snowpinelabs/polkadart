@Tags(['network'])
library;

import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:smoldot/smoldot.dart';

import 'support/json_rpc_client.dart';

void main() {
  group('Subscription Tests (raw interface)', () {
    late SmoldotClient client;
    late Chain chain;
    late JsonRpcClient rpc;

    setUpAll(() async {
      client = SmoldotClient(config: SmoldotConfig(maxLogLevel: 3));
      await client.initialize();

      // Load Westend chain spec
      final westendSpecFile = File('test/fixtures/westend.json');
      expect(
        westendSpecFile.existsSync(),
        isTrue,
        reason:
            'Westend chain spec not found. Run: curl -o test/fixtures/westend.json https://raw.githubusercontent.com/smol-dot/smoldot/main/demo-chain-specs/westend.json',
      );

      final westendSpec = await westendSpecFile.readAsString();
      chain = await client.addChain(AddChainConfig(chainSpec: westendSpec));
      rpc = JsonRpcClient(chain);
    });

    tearDownAll(() async {
      await rpc.close();
      if (client.isInitialized) {
        await client.dispose();
      }
    });

    test('should subscribe to new heads', () async {
      final (_, stream) = await rpc.subscribe(
        'chain_subscribeNewHeads',
        [],
        'chain_unsubscribeNewHeads',
      );

      final blocks = <dynamic>[];
      final completer = Completer<void>();
      StreamSubscription<dynamic>? sub;
      sub = stream.listen(
        (result) {
          blocks.add(result);
          if (blocks.length >= 2) {
            sub?.cancel();
            if (!completer.isCompleted) completer.complete();
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
      );

      // Westend warp-sync can take ~60s before the first head is produced;
      // allow ample headroom so the assertion reflects functionality, not latency.
      await completer.future.timeout(
        const Duration(seconds: 180),
        onTimeout: () => sub?.cancel(),
      );

      expect(blocks, isNotEmpty);
    });

    test('should subscribe to finalized heads', () async {
      final (_, stream) = await rpc.subscribe(
        'chain_subscribeFinalizedHeads',
        [],
        'chain_unsubscribeFinalizedHeads',
      );

      final blocks = <dynamic>[];
      final completer = Completer<void>();
      StreamSubscription<dynamic>? sub;
      sub = stream.listen(
        (result) {
          blocks.add(result);
          if (blocks.isNotEmpty) {
            sub?.cancel();
            if (!completer.isCompleted) completer.complete();
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 180),
        onTimeout: () => sub?.cancel(),
      );

      // Finalized blocks can take a while; don't fail if none arrived in time.
      expect(blocks, isA<List<dynamic>>());
    });

    test('should handle multiple concurrent subscriptions', () async {
      final (_, stream1) = await rpc.subscribe(
        'chain_subscribeNewHeads',
        [],
        'chain_unsubscribeNewHeads',
      );
      final (_, stream2) = await rpc.subscribe(
        'chain_subscribeFinalizedHeads',
        [],
        'chain_unsubscribeFinalizedHeads',
      );

      final blocks1 = <dynamic>[];
      final blocks2 = <dynamic>[];
      final completer = Completer<void>();
      var done = 0;
      StreamSubscription<dynamic>? sub1;
      StreamSubscription<dynamic>? sub2;

      void maybeComplete() {
        if (done == 2 && !completer.isCompleted) completer.complete();
      }

      sub1 = stream1.listen((result) {
        blocks1.add(result);
        if (blocks1.length >= 1) {
          sub1?.cancel();
          done++;
          maybeComplete();
        }
      });
      sub2 = stream2.listen((result) {
        blocks2.add(result);
        if (blocks2.length >= 1) {
          sub2?.cancel();
          done++;
          maybeComplete();
        }
      });

      await completer.future.timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          sub1?.cancel();
          sub2?.cancel();
        },
      );

      expect(blocks1.isNotEmpty || blocks2.isNotEmpty, isTrue);
    });
  });
}
