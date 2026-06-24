# sr25519

sr25519 cryptography for Dart with **two interchangeable backends**:

- **Rust (default, audited)** — FFI bindings to the [`schnorrkel`](https://docs.rs/schnorrkel) crate,
  the exact implementation [`sp_core::sr25519`](https://docs.rs/sp-core/latest/sp_core/sr25519/index.html)
  wraps. Keys, signatures, and verification are **byte-identical** to `sp_core::sr25519`.
- **Pure Dart** — the implementation this package has always shipped. No native dependency, works
  everywhere. **Unaudited.**

`Sr25519Crypto()` uses the Rust backend when its native library is available and **transparently
falls back** to the pure-Dart backend otherwise. The package is **Flutter-free** — pure `dart:ffi`.

## Backends

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:sr25519/sr25519.dart';

void main() {
  // Rust if available, else pure-Dart.
  final crypto = Sr25519Crypto();
  print(crypto.backendKind);            // Sr25519BackendKind.rust | .dart
  print(Sr25519Crypto.isRustAvailable); // bool

  final keyPair = crypto.generateKeyPair();           // { publicKey(32), secretKey(64) }
  final message = Uint8List.fromList(utf8.encode('hello sr25519'));

  final signature = crypto.sign(keyPair.secretKey, message); // 64 bytes
  final ok = crypto.verify(keyPair.publicKey, signature, message);
  assert(ok);

  // Deterministic derivation from a 32-byte seed (sp_core::sr25519::Pair::from_seed):
  final seed = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  final derived = crypto.keyPairFromSeed(seed);
  final pub = crypto.publicKeyFromSecret(derived.secretKey);
  assert(pub.toString() == derived.publicKey.toString());
}
```

Pin a backend explicitly:

```dart
final rust = Sr25519Crypto.rust();   // throws if the native library is unavailable
final dart = Sr25519Crypto.dart();   // always works (unaudited)
final byKind = Sr25519Crypto.using(Sr25519BackendKind.rust);
```

Because both backends are byte-compatible, a signature produced by one **verifies under the other**,
and the same seed yields identical keys on both.

### Byte formats

| value           | size | encoding |
|-----------------|------|----------|
| mini-secret seed| 32   | raw |
| public key      | 32   | compressed Ristretto |
| secret key      | 64   | `key \|\| nonce` (schnorrkel `SecretKey::to_bytes`) |
| signature       | 64   | schnorrkel (high-bit marker in byte 63) |

## Installing the audited Rust backend

Pure-Dart works with no setup. To enable the audited Rust backend, install the signed prebuilt
native library for your platform (no Rust toolchain required):

```bash
dart run sr25519:setup           # download + verify (Ed25519) + install
dart run sr25519:setup --force   # re-download
```

Prebuilts cover desktop Linux/macOS/Windows on x64+arm64. To build from source instead (or for
other platforms), see [BUILD.md](BUILD.md): `cd rust && cargo build --release`, or
`./tool/build_rust.sh`.

## Benchmark

```bash
dart run benchmark/sr25519_benchmark.dart [--iterations N] [--message-bytes N]
```

Reports key-generation, signing, and verification throughput for each available backend, plus the
Rust/Dart speedup.

## Low-level pure-Dart API

The original transcript-based API is unchanged and still available:

```dart
import 'dart:convert';
import 'package:merlin/merlin.dart' as merlin;
import 'package:sr25519/sr25519.dart';

void main() {
  final msg = utf8.encode('hello friends');
  final ctx = utf8.encode('example');

  final keypair = Sr25519.generateKeyPair();
  final (priv, pub) = (keypair.secretKey, keypair.publicKey);

  final sig = priv.sign(Sr25519.newSigningContext(ctx, msg));
  final (ok, _) = pub.verify(sig, Sr25519.newSigningContext(ctx, msg));
  assert(ok == true);
}
```

This pure-Dart implementation is **unaudited**; prefer the default (Rust) backend for production use.
