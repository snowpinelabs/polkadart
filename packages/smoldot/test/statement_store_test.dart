import 'dart:io';
import 'package:test/test.dart';
import 'package:smoldot/smoldot.dart';

void main() {
  group('StatementStoreConfig', () {
    test('has upstream-matching defaults', () {
      const config = StatementStoreConfig();
      expect(config.maxSeenStatements, equals(65536));
      expect(config.falsePositiveRate, equals(0.01));
      expect(config.affinityUpdateIntervalMs, equals(1000));
    });

    test('serializes to JSON', () {
      const config = StatementStoreConfig(
        maxSeenStatements: 1024,
        falsePositiveRate: 0.05,
        affinityUpdateIntervalMs: 2000,
      );
      expect(config.toJson(), {
        'maxSeenStatements': 1024,
        'falsePositiveRate': 0.05,
        'affinityUpdateIntervalMs': 2000,
      });
    });

    test('rejects invalid values via assertions', () {
      expect(
        () => StatementStoreConfig(falsePositiveRate: 1.5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => StatementStoreConfig(falsePositiveRate: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => StatementStoreConfig(maxSeenStatements: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => StatementStoreConfig(affinityUpdateIntervalMs: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('AddChainConfig includes statementStore in JSON only when set', () {
      const without = AddChainConfig(chainSpec: 'x');
      expect(without.toJson().containsKey('statementStore'), isFalse);

      const with_ = AddChainConfig(
        chainSpec: 'x',
        statementStore: StatementStoreConfig(),
      );
      expect(with_.toJson()['statementStore'], isA<Map<String, dynamic>>());
    });
  });

  group('Statement store end-to-end', () {
    late SmoldotClient client;

    tearDown(() async {
      if (client.isInitialized) {
        await client.dispose();
      }
    });

    test('adds a chain with the statement store enabled and stays operational',
        () async {
      client = SmoldotClient(config: SmoldotConfig(maxLogLevel: 3));
      await client.initialize();

      final spec = await File('test/fixtures/westend.json').readAsString();

      // Enabling the statement-store protocol must not break add_chain: the native
      // layer parses the config, builds StatementProtocolConfig (with a random bloom
      // seed) and the chain must still answer spec-derived JSON-RPC immediately.
      final chain = await client.addChain(
        AddChainConfig(
          chainSpec: spec,
          statementStore: const StatementStoreConfig(),
        ),
      );

      final name = await chain.request('system_chain', []);
      expect(name.isSuccess, isTrue);
      expect(name.result, equals('Westend'));
    });
  });
}
