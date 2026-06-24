// Demonstrates the dual-backend sr25519 API.
//
//   dart run example/backend_example.dart
//
// `Sr25519Crypto()` uses the audited Rust backend when its native library is available, otherwise it
// transparently falls back to the pure-Dart backend. You can also pin a backend explicitly.

import 'dart:convert';
import 'dart:typed_data';

import 'package:sr25519/sr25519.dart';

void main() {
  // Default: Rust if available, else pure-Dart.
  final crypto = Sr25519Crypto();
  print('Selected backend     : ${crypto.backendKind.name}');
  print('Rust backend available: ${Sr25519Crypto.isRustAvailable}');

  // Generate a keypair and sign/verify a message.
  final keyPair = crypto.generateKeyPair();
  final message = Uint8List.fromList(utf8.encode('hello sr25519'));

  final signature = crypto.sign(keyPair.secretKey, message);
  final verified = crypto.verify(keyPair.publicKey, signature, message);
  print('verify (same backend): $verified');
  assert(verified);

  // Deterministic key derivation from a 32-byte seed (sp_core::sr25519::Pair::from_seed).
  final seed = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  final derived = crypto.keyPairFromSeed(seed);
  print('derived public key   : ${_hex(derived.publicKey)}');

  // The two backends are interchangeable: a signature from one verifies under the other.
  final dart = Sr25519Crypto.dart();
  if (Sr25519Crypto.isRustAvailable) {
    final rust = Sr25519Crypto.rust();

    // Same seed -> identical keys on both backends.
    final rustKeys = rust.keyPairFromSeed(seed);
    final dartKeys = dart.keyPairFromSeed(seed);
    print('keys identical        : ${_eq(rustKeys.publicKey, dartKeys.publicKey)}');

    // Rust signs, Dart verifies (and vice versa).
    final rustSig = rust.sign(rustKeys.secretKey, message);
    print('rust-sign / dart-verify: ${dart.verify(dartKeys.publicKey, rustSig, message)}');

    final dartSig = dart.sign(dartKeys.secretKey, message);
    print('dart-sign / rust-verify: ${rust.verify(rustKeys.publicKey, dartSig, message)}');
  } else {
    print('(install the Rust backend with `dart run sr25519:setup` to see cross-backend interop)');
  }
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
