import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:merlin/merlin.dart' as merlin;
import 'package:sr25519/sr25519.dart';
import 'package:test/test.dart';

/// Whether the native Rust backend is loadable in this test run.
final bool rustAvailable = Sr25519Crypto.isRustAvailable;

/// Every backend available in this environment (Dart is always present).
List<Sr25519Backend> allBackends() => <Sr25519Backend>[
  const DartSr25519Backend(),
  if (rustAvailable) RustSr25519Backend.load(),
];

Uint8List _seed(int fill) => Uint8List.fromList(List<int>.generate(32, (i) => (i + fill) & 0xff));

void main() {
  test('Rust backend availability is reported (informational)', () {
    // Not an assertion on a specific value: just surface what ran.
    printOnFailure('rustAvailable=$rustAvailable');
    expect(rustAvailable, anyOf(isTrue, isFalse));
  });

  group('default backend selection', () {
    test('Sr25519Crypto() prefers Rust when available, else Dart', () {
      final selected = Sr25519Crypto().backendKind;
      expect(selected, rustAvailable ? Sr25519BackendKind.rust : Sr25519BackendKind.dart);
      expect(Sr25519Crypto.defaultBackend().kind, selected);
    });

    test('Sr25519Crypto.dart() always uses the pure-Dart backend', () {
      expect(Sr25519Crypto.dart().backendKind, Sr25519BackendKind.dart);
    });

    test('Sr25519Crypto.using selects by kind', () {
      expect(Sr25519Crypto.using(Sr25519BackendKind.dart).backendKind, Sr25519BackendKind.dart);
      if (rustAvailable) {
        expect(Sr25519Crypto.using(Sr25519BackendKind.rust).backendKind, Sr25519BackendKind.rust);
      }
    });
  });

  group('per-backend correctness', () {
    for (final backend in allBackends()) {
      final name = backend.kind.name;

      test('[$name] keyPairFromSeed is deterministic', () {
        final a = backend.keyPairFromSeed(_seed(1));
        final b = backend.keyPairFromSeed(_seed(1));
        expect(a.publicKey, b.publicKey);
        expect(a.secretKey, b.secretKey);
        expect(a.publicKey, hasLength(32));
        expect(a.secretKey, hasLength(64));
      });

      test('[$name] sign then verify round-trips', () {
        final kp = backend.generateKeyPair();
        final msg = Uint8List.fromList(utf8.encode('round trip $name'));
        final sig = backend.sign(kp.secretKey, msg);
        expect(sig, hasLength(64));
        // schnorrkel signatures carry a high-bit marker in byte 63.
        expect(sig[63] & 0x80, 0x80);
        expect(backend.verify(kp.publicKey, sig, msg), isTrue);
      });

      test('[$name] verify rejects a tampered message', () {
        final kp = backend.generateKeyPair();
        final msg = Uint8List.fromList(utf8.encode('original'));
        final sig = backend.sign(kp.secretKey, msg);
        final tampered = Uint8List.fromList(utf8.encode('originaL'));
        expect(backend.verify(kp.publicKey, sig, tampered), isFalse);
      });

      test('[$name] verify rejects a corrupted signature without throwing', () {
        final kp = backend.generateKeyPair();
        final msg = Uint8List.fromList(utf8.encode('msg'));
        final sig = backend.sign(kp.secretKey, msg);
        final corrupt = Uint8List.fromList(sig)..[0] ^= 0xff;
        expect(backend.verify(kp.publicKey, corrupt, msg), isFalse);
      });

      test('[$name] publicKeyFromSecret matches the keypair public key', () {
        final kp = backend.keyPairFromSeed(_seed(9));
        expect(backend.publicKeyFromSecret(kp.secretKey), kp.publicKey);
      });

      test('[$name] empty message can be signed and verified', () {
        final kp = backend.generateKeyPair();
        final empty = Uint8List(0);
        final sig = backend.sign(kp.secretKey, empty);
        expect(backend.verify(kp.publicKey, sig, empty), isTrue);
      });

      test('[$name] wrong-length inputs throw ArgumentError', () {
        final kp = backend.generateKeyPair();
        expect(() => backend.keyPairFromSeed(Uint8List(31)), throwsA(isA<ArgumentError>()));
        expect(() => backend.sign(Uint8List(10), Uint8List(0)), throwsA(isA<ArgumentError>()));
        expect(
          () => backend.verify(Uint8List(31), kp.secretKey, Uint8List(0)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('[$name] verifies a known sp_core::sr25519 vector', () {
        // From signature_test.dart: pubkey verifies sig over "this is a message".
        final pub = Uint8List.fromList(
          hex.decode('46ebddef8cd9bb167dc30878d7113b7e168e6f0646beffd77d69d39bad76b47a'),
        );
        final sig = Uint8List.fromList(
          hex.decode(
            '4e172314444b8f820bb54c22e95076f220ed25373e5c178234aa6c211d29271244b947e3ff3418ff6b45fd1df1140c8cbff69fc58ee6dc96df70936a2bb74b82',
          ),
        );
        final msg = Uint8List.fromList(utf8.encode('this is a message'));
        expect(backend.verify(pub, sig, msg), isTrue);
      });
    }
  });

  group('cross-backend compatibility', () {
    test('same seed yields byte-identical keys on both backends', () {
      if (!rustAvailable) {
        markTestSkipped('Rust backend not available');
        return;
      }
      final rust = RustSr25519Backend.load();
      final dart = const DartSr25519Backend();
      final seed = _seed(42);
      final rk = rust.keyPairFromSeed(seed);
      final dk = dart.keyPairFromSeed(seed);
      expect(rk.publicKey, dk.publicKey);
      expect(rk.secretKey, dk.secretKey);
    });

    test('a signature from one backend verifies under the other', () {
      if (!rustAvailable) {
        markTestSkipped('Rust backend not available');
        return;
      }
      final rust = RustSr25519Backend.load();
      final dart = const DartSr25519Backend();
      final seed = _seed(7);
      final keys = rust.keyPairFromSeed(seed);
      final msg = Uint8List.fromList(utf8.encode('interop'));

      final rustSig = rust.sign(keys.secretKey, msg);
      expect(dart.verify(keys.publicKey, rustSig, msg), isTrue);

      final dartSig = dart.sign(keys.secretKey, msg);
      expect(rust.verify(keys.publicKey, dartSig, msg), isTrue);
    });
  });

  group('interop with the legacy pure-Dart API', () {
    test('backend signature verifies via Sr25519.verify / PublicKey / Signature', () {
      final backend = Sr25519Crypto().backend;
      final keys = backend.keyPairFromSeed(_seed(3));
      final msg = Uint8List.fromList(utf8.encode('legacy interop'));
      final sigBytes = backend.sign(keys.secretKey, msg);

      final pub = PublicKey.newPublicKey(keys.publicKey);
      final sig = Signature.fromBytes(sigBytes);
      final (ok, err) = Sr25519.verify(pub, sig, msg);
      expect(err, isNull);
      expect(ok, isTrue);
    });

    test('legacy Sr25519.sign output verifies through the backend', () {
      final backend = Sr25519Crypto().backend;
      final keys = backend.keyPairFromSeed(_seed(4));
      final secret = SecretKey.from(keys.secretKey.sublist(0, 32), keys.secretKey.sublist(32, 64));
      final msg = Uint8List.fromList(utf8.encode('from legacy api'));
      final legacySig = Sr25519.sign(secret, msg).encode();

      expect(backend.verify(keys.publicKey, legacySig, msg), isTrue);
      // And the public key derived by the legacy API matches the backend's.
      expect(Uint8List.fromList(secret.public().encode()), keys.publicKey);
    });

    test('newSigningContext("substrate") matches the backend signing context', () {
      // Confirms the backend uses the Substrate context that Sr25519.sign builds.
      final backend = Sr25519Crypto().backend;
      final keys = backend.keyPairFromSeed(_seed(5));
      final msg = Uint8List.fromList(utf8.encode('context check'));
      final sigBytes = backend.sign(keys.secretKey, msg);

      final pub = PublicKey.newPublicKey(keys.publicKey);
      final transcript = Sr25519.newSigningContext(utf8.encode('substrate'), msg);
      final (ok, _) = pub.verify(Signature.fromBytes(sigBytes), transcript);
      expect(ok, isTrue);
      // Sanity that we actually built a substrate transcript.
      expect(transcript, isA<merlin.Transcript>());
    });
  });
}
