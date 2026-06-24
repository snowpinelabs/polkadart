// The audited backend: sr25519 operations executed by the native `schnorrkel` library over FFI.
// Loading is attempted lazily and cached; if the native library is missing or incompatible, the
// backend reports itself unavailable so callers can fall back to the pure-Dart backend.

import 'dart:typed_data';

import 'backend.dart';
import 'bindings.dart';
import 'platform.dart';

/// [Sr25519Backend] backed by the native (Rust / schnorrkel) library.
class RustSr25519Backend implements Sr25519Backend {
  RustSr25519Backend._(this._bindings);

  final Sr25519Bindings _bindings;

  static bool _attempted = false;
  static RustSr25519Backend? _cached;
  static Object? _loadError;

  /// Load (and cache) the native backend, returning `null` if the library cannot be loaded or its
  /// ABI version does not match. The first call does the work; later calls return the cached result.
  static RustSr25519Backend? tryLoad() {
    if (_attempted) return _cached;
    _attempted = true;
    try {
      final library = Sr25519Platform.loadLibrary();
      final bindings = Sr25519Bindings(library);
      final abi = bindings.abiVersion;
      if (abi != Sr25519Bindings.expectedAbiVersion) {
        throw Sr25519FfiException(
          'incompatible native ABI version',
          details: 'loaded $abi, expected ${Sr25519Bindings.expectedAbiVersion}',
        );
      }
      _cached = RustSr25519Backend._(bindings);
    } catch (e) {
      _loadError = e;
      _cached = null;
    }
    return _cached;
  }

  /// Load the native backend or throw [Sr25519BackendUnavailableException] with guidance.
  static RustSr25519Backend load() {
    final backend = tryLoad();
    if (backend == null) {
      throw Sr25519BackendUnavailableException(
        'The audited Rust sr25519 native library could not be loaded. Install a signed prebuilt '
        'with `dart run sr25519:setup`, or build it from source (see packages/sr25519/BUILD.md). '
        'Use Sr25519Crypto() instead of Sr25519Crypto.rust() to fall back to the pure-Dart backend '
        'automatically.',
        details: _loadError,
      );
    }
    return backend;
  }

  /// Whether the native library is loadable in this process.
  static bool get isAvailable => tryLoad() != null;

  /// Forget any cached load attempt. Intended for tests that manipulate the environment.
  static void resetForTesting() {
    _attempted = false;
    _cached = null;
    _loadError = null;
  }

  @override
  Sr25519BackendKind get kind => Sr25519BackendKind.rust;

  @override
  Sr25519KeyData generateKeyPair() => _bindings.generateKeyPair();

  @override
  Sr25519KeyData keyPairFromSeed(Uint8List seed) => _bindings.keyPairFromSeed(seed);

  @override
  Uint8List publicKeyFromSecret(Uint8List secretKey) => _bindings.publicKeyFromSecret(secretKey);

  @override
  Uint8List sign(Uint8List secretKey, Uint8List message) => _bindings.sign(secretKey, message);

  @override
  bool verify(Uint8List publicKey, Uint8List signature, Uint8List message) =>
      _bindings.verify(publicKey, signature, message);
}
