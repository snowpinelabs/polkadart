// Sign prebuilt native libraries with the Ed25519 signing key, emitting a detached `<file>.sig`
// (raw 64-byte signature) next to each input. Used by .github/workflows/release_smoldot.yml.
//
//   SMOLDOT_SIGNING_KEY=<hex key> dart run tool/sign_prebuilt.dart <file>...
//
// SMOLDOT_SIGNING_KEY may be either a 32-byte (64-hex) Ed25519 seed (as produced by
// tool/gen_key.dart) or a 64-byte (128-hex) libsodium-style secret key whose first 32 bytes are the
// seed (e.g. the shared iroh_dart cargokit key) — both resolve to the same keypair.
//
// The matching public key is kPrebuiltPublicKeyHex in lib/src/prebuilt.dart; the installer
// (bin/setup.dart) verifies downloads against it. Generate a fresh pair with tool/gen_key.dart.

import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> args) async {
  final hexKey = Platform.environment['SMOLDOT_SIGNING_KEY'];
  if (hexKey == null || hexKey.isEmpty) {
    stderr.writeln('sign_prebuilt: SMOLDOT_SIGNING_KEY (hex Ed25519 seed or secret key) is not set.');
    exitCode = 1;
    return;
  }
  if (args.isEmpty) {
    stderr.writeln('sign_prebuilt: usage: dart run tool/sign_prebuilt.dart <file>...');
    exitCode = 1;
    return;
  }

  final seed = _seedFromHex(hexKey);
  if (seed == null) {
    stderr.writeln(
      'sign_prebuilt: SMOLDOT_SIGNING_KEY must be a 32-byte (64-hex) seed or a 64-byte (128-hex) '
      'secret key; got ${hexKey.trim().length} hex chars.',
    );
    exitCode = 1;
    return;
  }

  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(seed);
  for (final path in args) {
    final bytes = await File(path).readAsBytes();
    final signature = await algorithm.sign(bytes, keyPair: keyPair);
    final sigPath = '$path.sig';
    await File(sigPath).writeAsBytes(signature.bytes, flush: true);
    stdout.writeln('signed $path -> $sigPath (${signature.bytes.length} bytes)');
  }
}

/// Extracts the 32-byte Ed25519 seed from a 64-hex seed or a 128-hex (seed||public) secret key.
/// Returns null if the input is neither length or contains non-hex characters.
Uint8List? _seedFromHex(String hex) {
  final clean = hex.trim();
  if (clean.length != 64 && clean.length != 128) return null;
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) return null;
  // A libsodium-style Ed25519 secret key is seed(32) || public(32); take just the seed.
  return Uint8List.sublistView(_hexToBytes(clean), 0, 32);
}

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
