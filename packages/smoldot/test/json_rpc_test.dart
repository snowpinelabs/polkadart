@Tags(['network'])
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:smoldot/smoldot.dart';

import 'support/json_rpc_client.dart';

void main() {
  group('JSON-RPC (raw interface)', () {
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

    test('system_chain', () async {
      expect(await rpc.call('system_chain'), equals('Westend'));
    });

    test('system_version', () async {
      expect(await rpc.call('system_version'), isNotEmpty);
    });

    test('system_name', () async {
      expect(await rpc.call('system_name'), isNotEmpty);
    });

    test('system_properties', () async {
      expect(await rpc.call('system_properties'), isA<Map<String, dynamic>>());
    });

    test(
      'chain_getFinalizedHead',
      () async {
        final head = await rpc.call('chain_getFinalizedHead') as String;
        expect(head.startsWith('0x'), isTrue);
      },
      // Needs warp-sync to a finalized block, which can take >30s on Westend.
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('handles multiple concurrent requests', () async {
      final results = await Future.wait([
        rpc.call('system_chain'),
        rpc.call('system_version'),
        rpc.call('system_name'),
        rpc.call('system_properties'),
      ]);

      expect(results.length, equals(4));
      expect(results[0], equals('Westend'));
      expect(results[1], isNotEmpty);
      expect(results[2], isNotEmpty);
      expect(results[3], isA<Map<String, dynamic>>());
    });

    test('request with parameters (chain_getBlockHash)', () async {
      final hash = await rpc.call('chain_getBlockHash', [0]) as String;
      expect(hash.startsWith('0x'), isTrue);
    });
  });
}
