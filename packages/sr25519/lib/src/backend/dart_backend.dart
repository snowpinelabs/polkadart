// The pure-Dart backend: implements [Sr25519Backend] in terms of this package's own (unaudited)
// Dart implementation of sr25519. Always available — it has no native dependency — and produces
// results byte-compatible with the Rust backend (and with `sp_core::sr25519`).

import 'dart:math';
import 'dart:typed_data';

// The umbrella library provides both the native Dart sr25519 classes (MiniSecretKey, SecretKey,
// PublicKey, Signature, Sr25519) and, via re-export, the backend interface types used here.
import 'package:sr25519/sr25519.dart';

/// [Sr25519Backend] backed by the pure-Dart implementation in this package.
class DartSr25519Backend implements Sr25519Backend {
  const DartSr25519Backend();

  @override
  Sr25519BackendKind get kind => Sr25519BackendKind.dart;

  @override
  Sr25519KeyData generateKeyPair() {
    final rng = Random.secure();
    final seed = Uint8List.fromList(List<int>.generate(Sr25519Sizes.seed, (_) => rng.nextInt(256)));
    return keyPairFromSeed(seed);
  }

  @override
  Sr25519KeyData keyPairFromSeed(Uint8List seed) {
    requireLength(seed, Sr25519Sizes.seed, 'seed');
    // MiniSecretKey.fromRawKey stores the seed verbatim, matching schnorrkel's
    // `MiniSecretKey::from_bytes`; expandEd25519 is the ed25519-style expansion (ExpansionMode::Ed25519).
    final secret = MiniSecretKey.fromRawKey(seed).expandEd25519();
    return Sr25519KeyData(
      publicKey: Uint8List.fromList(secret.public().encode()),
      secretKey: _secretToBytes(secret),
    );
  }

  @override
  Uint8List publicKeyFromSecret(Uint8List secretKey) {
    return Uint8List.fromList(_secretFromBytes(secretKey).public().encode());
  }

  @override
  Uint8List sign(Uint8List secretKey, Uint8List message) {
    // Sr25519.sign uses the "substrate" signing context, matching sp_core::sr25519 and the Rust
    // backend; the resulting signature carries schnorrkel's high-bit marker (via Signature.encode).
    return Sr25519.sign(_secretFromBytes(secretKey), message).encode();
  }

  @override
  bool verify(Uint8List publicKey, Uint8List signature, Uint8List message) {
    requireLength(publicKey, Sr25519Sizes.publicKey, 'publicKey');
    requireLength(signature, Sr25519Sizes.signature, 'signature');
    final PublicKey pk;
    final Signature sig;
    try {
      pk = PublicKey.newPublicKey(publicKey);
      sig = Signature.fromBytes(signature);
    } catch (_) {
      // A malformed point or signature is "does not verify", not an error.
      return false;
    }
    final (verified, _) = Sr25519.verify(pk, sig, message);
    return verified;
  }

  Uint8List _secretToBytes(SecretKey secret) {
    final out = Uint8List(Sr25519Sizes.secretKey);
    out.setRange(0, 32, secret.key);
    out.setRange(32, 64, secret.nonce);
    return out;
  }

  SecretKey _secretFromBytes(Uint8List bytes) {
    requireLength(bytes, Sr25519Sizes.secretKey, 'secretKey');
    return SecretKey.from(bytes.sublist(0, 32), bytes.sublist(32, 64));
  }
}

/// Canonical byte lengths for sr25519 values, shared across backends.
class Sr25519Sizes {
  Sr25519Sizes._();

  /// Mini-secret seed length.
  static const int seed = 32;

  /// Public key length.
  static const int publicKey = 32;

  /// Secret key length (`key || nonce`).
  static const int secretKey = 64;

  /// Signature length.
  static const int signature = 64;
}
