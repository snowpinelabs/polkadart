// The high-level entry point for the dual-backend sr25519 API.
//
// By default [Sr25519Crypto] uses the audited Rust backend, transparently falling back to the
// pure-Dart backend when the native library is not available (not installed / not compiled for this
// platform). Callers can also pin a specific backend.

import 'dart:typed_data';

import 'backend.dart';
import 'dart_backend.dart';
import 'rust_backend.dart';

/// Byte-oriented sr25519 operations backed by a selectable [Sr25519Backend].
///
/// ```dart
/// final crypto = Sr25519Crypto();                 // Rust if available, else pure-Dart.
/// final kp = crypto.generateKeyPair();
/// final sig = crypto.sign(kp.secretKey, message);
/// final ok = crypto.verify(kp.publicKey, sig, message);
///
/// print(crypto.backendKind);                       // which one was selected
/// final dartOnly = Sr25519Crypto.dart();           // force the pure-Dart backend
/// final rustOnly = Sr25519Crypto.rust();           // throws if the native lib is unavailable
/// ```
class Sr25519Crypto {
  Sr25519Crypto._(this.backend);

  /// The backend all operations delegate to.
  final Sr25519Backend backend;

  /// Use the default backend: the audited Rust backend if its native library is available, otherwise
  /// the pure-Dart backend.
  factory Sr25519Crypto() => Sr25519Crypto._(defaultBackend());

  /// Force the audited Rust backend. Throws [Sr25519BackendUnavailableException] if the native
  /// library cannot be loaded.
  factory Sr25519Crypto.rust() => Sr25519Crypto._(RustSr25519Backend.load());

  /// Force the pure-Dart backend (always available; unaudited).
  factory Sr25519Crypto.dart() => Sr25519Crypto._(const DartSr25519Backend());

  /// Use an explicit [kind]; [Sr25519BackendKind.rust] throws if the native library is unavailable.
  factory Sr25519Crypto.using(Sr25519BackendKind kind) => switch (kind) {
    Sr25519BackendKind.rust => Sr25519Crypto.rust(),
    Sr25519BackendKind.dart => Sr25519Crypto.dart(),
  };

  /// Wrap an already-constructed [backend].
  factory Sr25519Crypto.withBackend(Sr25519Backend backend) => Sr25519Crypto._(backend);

  /// The backend chosen by [Sr25519Crypto.new]: Rust if loadable, otherwise pure-Dart.
  static Sr25519Backend defaultBackend() =>
      RustSr25519Backend.tryLoad() ?? const DartSr25519Backend();

  /// Whether the audited Rust backend is available in this process.
  static bool get isRustAvailable => RustSr25519Backend.isAvailable;

  /// Which backend this instance uses.
  Sr25519BackendKind get backendKind => backend.kind;

  /// See [Sr25519Backend.generateKeyPair].
  Sr25519KeyData generateKeyPair() => backend.generateKeyPair();

  /// See [Sr25519Backend.keyPairFromSeed].
  Sr25519KeyData keyPairFromSeed(Uint8List seed) => backend.keyPairFromSeed(seed);

  /// See [Sr25519Backend.publicKeyFromSecret].
  Uint8List publicKeyFromSecret(Uint8List secretKey) => backend.publicKeyFromSecret(secretKey);

  /// See [Sr25519Backend.sign].
  Uint8List sign(Uint8List secretKey, Uint8List message) => backend.sign(secretKey, message);

  /// See [Sr25519Backend.verify].
  bool verify(Uint8List publicKey, Uint8List signature, Uint8List message) =>
      backend.verify(publicKey, signature, message);
}
