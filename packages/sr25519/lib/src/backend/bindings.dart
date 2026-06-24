// Low-level FFI bindings to the native `sr25519` library (see native/sr25519.h). Every method
// allocates short-lived native buffers in an [Arena], copies the caller's bytes in, calls the C
// function, and copies the results back out into freshly owned [Uint8List]s, so no native memory
// outlives the call.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'backend.dart';

// Native (C) and Dart signatures for each exported function.

typedef _AbiVersionNative = Uint32 Function();
typedef _AbiVersionDart = int Function();

typedef _KeyPairFromSeedNative =
    Int32 Function(Pointer<Uint8> seed, Pointer<Uint8> outPublic, Pointer<Uint8> outSecret);
typedef _KeyPairFromSeedDart =
    int Function(Pointer<Uint8> seed, Pointer<Uint8> outPublic, Pointer<Uint8> outSecret);

typedef _GenerateNative = Int32 Function(Pointer<Uint8> outPublic, Pointer<Uint8> outSecret);
typedef _GenerateDart = int Function(Pointer<Uint8> outPublic, Pointer<Uint8> outSecret);

typedef _PublicFromSecretNative = Int32 Function(Pointer<Uint8> secret, Pointer<Uint8> outPublic);
typedef _PublicFromSecretDart = int Function(Pointer<Uint8> secret, Pointer<Uint8> outPublic);

typedef _SignNative =
    Int32 Function(Pointer<Uint8> secret, Pointer<Uint8> msg, Size msgLen, Pointer<Uint8> outSig);
typedef _SignDart =
    int Function(Pointer<Uint8> secret, Pointer<Uint8> msg, int msgLen, Pointer<Uint8> outSig);

typedef _VerifyNative =
    Int32 Function(Pointer<Uint8> publicKey, Pointer<Uint8> sig, Pointer<Uint8> msg, Size msgLen);
typedef _VerifyDart =
    int Function(Pointer<Uint8> publicKey, Pointer<Uint8> sig, Pointer<Uint8> msg, int msgLen);

/// Resolved function pointers and ergonomic wrappers for the native `sr25519` library.
class Sr25519Bindings {
  /// Bind every exported symbol from [library]. Throws [ArgumentError] (from `lookupFunction`) if a
  /// symbol is missing, which the Rust-backend loader treats as "incompatible/unavailable".
  Sr25519Bindings(DynamicLibrary library)
    : _abiVersion = library.lookupFunction<_AbiVersionNative, _AbiVersionDart>(
        'sr25519_abi_version',
      ),
      _keyPairFromSeed = library.lookupFunction<_KeyPairFromSeedNative, _KeyPairFromSeedDart>(
        'sr25519_keypair_from_seed',
      ),
      _generate = library.lookupFunction<_GenerateNative, _GenerateDart>('sr25519_generate'),
      _publicFromSecret = library.lookupFunction<_PublicFromSecretNative, _PublicFromSecretDart>(
        'sr25519_public_from_secret',
      ),
      _sign = library.lookupFunction<_SignNative, _SignDart>('sr25519_sign'),
      _verify = library.lookupFunction<_VerifyNative, _VerifyDart>('sr25519_verify');

  /// ABI version this binding layer is written against. See [abiVersion].
  static const int expectedAbiVersion = 1;

  /// Byte length of a mini-secret seed.
  static const int seedLength = 32;

  /// Byte length of a serialized public key.
  static const int publicKeyLength = 32;

  /// Byte length of a serialized secret key (`key || nonce`).
  static const int secretKeyLength = 64;

  /// Byte length of a serialized signature.
  static const int signatureLength = 64;

  // Result codes returned by the native functions (mirror rust/src/lib.rs).
  static const int _ok = 0;
  static const int _errNull = -1;

  final _AbiVersionDart _abiVersion;
  final _KeyPairFromSeedDart _keyPairFromSeed;
  final _GenerateDart _generate;
  final _PublicFromSecretDart _publicFromSecret;
  final _SignDart _sign;
  final _VerifyDart _verify;

  /// ABI version reported by the loaded library.
  int get abiVersion => _abiVersion();

  /// See [Sr25519Backend.keyPairFromSeed].
  Sr25519KeyData keyPairFromSeed(Uint8List seed) {
    requireLength(seed, seedLength, 'seed');
    return using((arena) {
      final seedPtr = _copyIn(arena, seed);
      final publicPtr = arena<Uint8>(publicKeyLength);
      final secretPtr = arena<Uint8>(secretKeyLength);
      _check(_keyPairFromSeed(seedPtr, publicPtr, secretPtr), 'sr25519_keypair_from_seed');
      return Sr25519KeyData(
        publicKey: _copyOut(publicPtr, publicKeyLength),
        secretKey: _copyOut(secretPtr, secretKeyLength),
      );
    });
  }

  /// See [Sr25519Backend.generateKeyPair].
  Sr25519KeyData generateKeyPair() {
    return using((arena) {
      final publicPtr = arena<Uint8>(publicKeyLength);
      final secretPtr = arena<Uint8>(secretKeyLength);
      _check(_generate(publicPtr, secretPtr), 'sr25519_generate');
      return Sr25519KeyData(
        publicKey: _copyOut(publicPtr, publicKeyLength),
        secretKey: _copyOut(secretPtr, secretKeyLength),
      );
    });
  }

  /// See [Sr25519Backend.publicKeyFromSecret].
  Uint8List publicKeyFromSecret(Uint8List secretKey) {
    requireLength(secretKey, secretKeyLength, 'secretKey');
    return using((arena) {
      final secretPtr = _copyIn(arena, secretKey);
      final publicPtr = arena<Uint8>(publicKeyLength);
      _check(_publicFromSecret(secretPtr, publicPtr), 'sr25519_public_from_secret');
      return _copyOut(publicPtr, publicKeyLength);
    });
  }

  /// See [Sr25519Backend.sign].
  Uint8List sign(Uint8List secretKey, Uint8List message) {
    requireLength(secretKey, secretKeyLength, 'secretKey');
    return using((arena) {
      final secretPtr = _copyIn(arena, secretKey);
      final messagePtr = _copyMessage(arena, message);
      final sigPtr = arena<Uint8>(signatureLength);
      _check(_sign(secretPtr, messagePtr, message.length, sigPtr), 'sr25519_sign');
      return _copyOut(sigPtr, signatureLength);
    });
  }

  /// See [Sr25519Backend.verify]. Returns `false` for a malformed key/signature; only throws if a
  /// null pointer is reported (a binding bug, since lengths are validated here).
  bool verify(Uint8List publicKey, Uint8List signature, Uint8List message) {
    requireLength(publicKey, publicKeyLength, 'publicKey');
    requireLength(signature, signatureLength, 'signature');
    return using((arena) {
      final publicPtr = _copyIn(arena, publicKey);
      final sigPtr = _copyIn(arena, signature);
      final messagePtr = _copyMessage(arena, message);
      final rc = _verify(publicPtr, sigPtr, messagePtr, message.length);
      if (rc == _errNull) {
        throw Sr25519FfiException('sr25519_verify received a null pointer');
      }
      // 1 = valid; 0 = well-formed but invalid; negative parse error = treat as invalid.
      return rc == 1;
    });
  }

  Pointer<Uint8> _copyIn(Arena arena, Uint8List bytes) {
    final ptr = arena<Uint8>(bytes.length);
    ptr.asTypedList(bytes.length).setAll(0, bytes);
    return ptr;
  }

  /// Allocate and copy [message], or return [nullptr] for an empty message (the native side accepts
  /// a null pointer when the length is zero).
  Pointer<Uint8> _copyMessage(Arena arena, Uint8List message) {
    if (message.isEmpty) return nullptr;
    return _copyIn(arena, message);
  }

  Uint8List _copyOut(Pointer<Uint8> ptr, int length) => Uint8List.fromList(ptr.asTypedList(length));

  void _check(int rc, String fn) {
    if (rc != _ok) {
      throw Sr25519FfiException('$fn failed', details: 'error code $rc');
    }
  }
}
