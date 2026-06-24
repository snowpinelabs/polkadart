// Backend-agnostic types and the [Sr25519Backend] interface implemented by both the audited Rust
// (schnorrkel / sp_core::sr25519-compatible) backend and the pure-Dart backend.
//
// All operations work in canonical byte encodings so the two backends are fully interchangeable and
// cross-compatible (a signature produced by one verifies under the other):
//
//   * mini-secret seed : 32 bytes
//   * public key       : 32 bytes (compressed Ristretto point)
//   * secret key       : 64 bytes (`key || nonce`, schnorrkel `SecretKey::to_bytes` encoding)
//   * signature        : 64 bytes (schnorrkel encoding; byte 63 carries the high-bit marker)
//
// Signing uses the Substrate signing context (`b"substrate"`), matching `sp_core::sr25519` and the
// `Sr25519.sign`/`Sr25519.verify` helpers of the pure-Dart implementation.

import 'dart:typed_data';

/// Which implementation backs an [Sr25519Backend].
enum Sr25519BackendKind {
  /// The audited Rust [`schnorrkel`](https://docs.rs/schnorrkel) library loaded over FFI — the same
  /// implementation [`sp_core::sr25519`](https://docs.rs/sp-core/latest/sp_core/sr25519/index.html)
  /// wraps. Produces byte-identical results.
  rust,

  /// The pure-Dart implementation shipped with this package. Always available; no native dependency.
  /// Unaudited.
  dart,
}

/// An sr25519 keypair in canonical byte form: a 32-byte [publicKey] and a 64-byte [secretKey].
class Sr25519KeyData {
  const Sr25519KeyData({required this.publicKey, required this.secretKey});

  /// 32-byte compressed public key.
  final Uint8List publicKey;

  /// 64-byte secret key (`key || nonce`, schnorrkel `SecretKey::to_bytes` encoding).
  final Uint8List secretKey;
}

/// Common interface implemented by every sr25519 backend.
///
/// Obtain one through [Sr25519Crypto] (which selects Rust-by-default with a pure-Dart fallback) or
/// construct a concrete backend directly.
abstract interface class Sr25519Backend {
  /// Which implementation this backend uses.
  Sr25519BackendKind get kind;

  /// Generate a fresh random keypair.
  Sr25519KeyData generateKeyPair();

  /// Derive a keypair deterministically from a 32-byte mini-secret [seed]
  /// (`ExpansionMode::Ed25519`, matching `sp_core::sr25519::Pair::from_seed`).
  Sr25519KeyData keyPairFromSeed(Uint8List seed);

  /// Derive the 32-byte public key from a 64-byte [secretKey].
  Uint8List publicKeyFromSecret(Uint8List secretKey);

  /// Sign [message] with a 64-byte [secretKey] using the `b"substrate"` context. Returns a 64-byte
  /// signature. Signing is randomized, so repeated calls return different (all valid) signatures.
  Uint8List sign(Uint8List secretKey, Uint8List message);

  /// Verify a 64-byte [signature] against a 32-byte [publicKey] and [message]. Returns `false` for a
  /// malformed key/signature rather than throwing.
  bool verify(Uint8List publicKey, Uint8List signature, Uint8List message);
}

/// Base class for errors thrown by the sr25519 backends.
class Sr25519Exception implements Exception {
  Sr25519Exception(this.message, {this.details});

  /// Human-readable description of what went wrong.
  final String message;

  /// Optional underlying cause (an OS error, FFI error code, etc.).
  final Object? details;

  @override
  String toString() =>
      details == null ? 'Sr25519Exception: $message' : 'Sr25519Exception: $message\n$details';
}

/// Thrown when the audited Rust backend was requested but its native library could not be loaded.
class Sr25519BackendUnavailableException extends Sr25519Exception {
  Sr25519BackendUnavailableException(super.message, {super.details});

  @override
  String toString() => details == null
      ? 'Sr25519BackendUnavailableException: $message'
      : 'Sr25519BackendUnavailableException: $message\n$details';
}

/// Thrown for failures crossing the Rust FFI boundary (library load, symbol lookup, error codes).
class Sr25519FfiException extends Sr25519Exception {
  Sr25519FfiException(super.message, {super.details});

  @override
  String toString() =>
      details == null ? 'Sr25519FfiException: $message' : 'Sr25519FfiException: $message\n$details';
}

/// Throws an [ArgumentError] unless [bytes] has exactly [length] elements.
void requireLength(Uint8List bytes, int length, String name) {
  if (bytes.length != length) {
    throw ArgumentError.value(bytes.length, '$name.length', 'expected exactly $length bytes');
  }
}
