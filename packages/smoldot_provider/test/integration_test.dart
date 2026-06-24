@Tags(['network'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:smoldot_provider/smoldot_provider.dart';
import 'package:test/test.dart';

void main() {
  group('getSmProvider against a live chain', () {
    late SmoldotClient client;
    late JsonRpcConnection connection;
    final received = StreamController<Map<String, dynamic>>.broadcast();

    setUpAll(() async {
      // Reuse the smoldot package's Westend fixture.
      final specFile = File('../smoldot/test/fixtures/westend.json');
      expect(
        specFile.existsSync(),
        isTrue,
        reason:
            'Westend chain spec not found. Run: curl -o packages/smoldot/test/fixtures/westend.json https://raw.githubusercontent.com/smol-dot/smoldot/main/demo-chain-specs/westend.json',
      );

      client = SmoldotClient(config: SmoldotConfig(maxLogLevel: 3));
      await client.initialize();

      final provider = getSmProvider(
        client.addChain(
          AddChainConfig(chainSpec: await specFile.readAsString()),
        ),
      );
      connection = provider(
        (message) => received.add(jsonDecode(message) as Map<String, dynamic>),
      );
    });

    tearDownAll(() async {
      connection.disconnect();
      await received.close();
      if (client.isInitialized) await client.dispose();
    });

    /// Send a request and await the response whose id matches.
    Future<dynamic> call(
      int id,
      String method, [
      List<dynamic> params = const [],
    ]) {
      final result = received.stream
          .firstWhere((m) => m['id'] == id)
          .then((m) => m['result']);
      connection.send(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          'params': params,
        }),
      );
      return result;
    }

    test('system_chain returns Westend', () async {
      expect(await call(1, 'system_chain'), equals('Westend'));
    });

    test('chainSpec_v1_genesisHash returns a hash', () async {
      final genesis = await call(2, 'chainSpec_v1_genesisHash') as String;
      expect(genesis.startsWith('0x'), isTrue);
    });
  });
}
