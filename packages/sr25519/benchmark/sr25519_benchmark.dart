// Throughput comparison of the two sr25519 backends — the audited Rust (schnorrkel) backend and the
// pure-Dart backend — across key generation, signing, and verification.
//
//   dart run benchmark/sr25519_benchmark.dart [--iterations N] [--message-bytes N]
//
// If the native Rust library is not available, only the pure-Dart backend is benchmarked (run
// `dart run sr25519:setup`, or build it with tool/build_rust.sh, to enable the Rust backend).

import 'dart:io';
import 'dart:typed_data';

import 'package:sr25519/sr25519.dart';

void main(List<String> args) {
  final iterations = _intArg(args, '--iterations', 5000);
  final messageBytes = _intArg(args, '--message-bytes', 32);

  stdout.writeln('sr25519 backend benchmark');
  stdout.writeln('  iterations : $iterations per measurement');
  stdout.writeln('  message    : $messageBytes bytes');
  stdout.writeln('  Rust backend available: ${Sr25519Crypto.isRustAvailable}');
  if (!Sr25519Crypto.isRustAvailable) {
    stdout.writeln(
      '  (install with `dart run sr25519:setup` or build with tool/build_rust.sh '
      'to benchmark the Rust backend)',
    );
  }
  stdout.writeln('');

  final backends = <Sr25519Backend>[
    if (Sr25519Crypto.isRustAvailable) RustSr25519Backend.load(),
    const DartSr25519Backend(),
  ];

  final message = Uint8List.fromList(List<int>.generate(messageBytes, (i) => i & 0xff));
  final seed = Uint8List.fromList(List<int>.generate(32, (i) => (i * 7 + 1) & 0xff));

  // Pre-compute inputs (shared across backends — keys are byte-identical between them).
  final keyData = backends.first.keyPairFromSeed(seed);
  final secretKey = keyData.secretKey;
  final publicKey = keyData.publicKey;
  final signature = backends.first.sign(secretKey, message);

  final results = <String, Map<Sr25519BackendKind, double>>{
    'keypairFromSeed': {},
    'sign': {},
    'verify': {},
  };

  for (final backend in backends) {
    final name = backend.kind.name;
    stdout.writeln('Benchmarking $name backend...');

    results['keypairFromSeed']![backend.kind] = _measure(
      iterations,
      () => backend.keyPairFromSeed(seed),
    );
    results['sign']![backend.kind] = _measure(iterations, () => backend.sign(secretKey, message));
    // Sanity: every backend must accept the reference signature.
    if (!backend.verify(publicKey, signature, message)) {
      stderr.writeln('  ! $name backend failed to verify the reference signature');
      exitCode = 1;
    }
    results['verify']![backend.kind] = _measure(
      iterations,
      () => backend.verify(publicKey, signature, message),
    );
  }

  stdout.writeln('');
  _printTable(results, backends.map((b) => b.kind).toList());
}

/// Run [body] [iterations] times (after a warmup) and return throughput in operations per second.
double _measure(int iterations, void Function() body) {
  final warmup = (iterations ~/ 10).clamp(1, iterations);
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  sw.stop();
  final seconds = sw.elapsedMicroseconds / 1e6;
  return seconds == 0 ? double.infinity : iterations / seconds;
}

void _printTable(
  Map<String, Map<Sr25519BackendKind, double>> results,
  List<Sr25519BackendKind> kinds,
) {
  final hasRust = kinds.contains(Sr25519BackendKind.rust);
  final hasDart = kinds.contains(Sr25519BackendKind.dart);

  String opsCell(double? v) => v == null ? '-' : _fmtOps(v);

  final header = StringBuffer()
    ..write(_pad('operation', 18))
    ..write(_pad('rust (ops/s)', 18))
    ..write(_pad('dart (ops/s)', 18));
  if (hasRust && hasDart) header.write(_pad('rust / dart', 14));
  stdout.writeln(header.toString());
  stdout.writeln('-' * header.length);

  for (final op in results.keys) {
    final rust = results[op]![Sr25519BackendKind.rust];
    final dart = results[op]![Sr25519BackendKind.dart];
    final row = StringBuffer()
      ..write(_pad(op, 18))
      ..write(_pad(opsCell(rust), 18))
      ..write(_pad(opsCell(dart), 18));
    if (hasRust && hasDart && rust != null && dart != null && dart != 0) {
      row.write(_pad('${(rust / dart).toStringAsFixed(2)}x', 14));
    }
    stdout.writeln(row.toString());
  }
}

String _fmtOps(double opsPerSec) {
  if (opsPerSec >= 1e6) return '${(opsPerSec / 1e6).toStringAsFixed(2)}M';
  if (opsPerSec >= 1e3) return '${(opsPerSec / 1e3).toStringAsFixed(1)}k';
  return opsPerSec.toStringAsFixed(1);
}

String _pad(String s, int width) => s.padRight(width);

int _intArg(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) {
    return int.tryParse(args[i + 1]) ?? fallback;
  }
  return fallback;
}
