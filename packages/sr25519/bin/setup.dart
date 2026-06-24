// `dart run sr25519:setup` — download the signed prebuilt native library for the current platform
// from the GitHub Release and install it into the per-user cache, so consumers do not need a Rust
// toolchain. The Rust backend's loader (lib/src/backend/platform.dart) picks it up automatically.
//
//   dart run sr25519:setup              # download + verify + install
//   dart run sr25519:setup --force      # re-download even if already installed
//   dart run sr25519:setup --no-verify  # skip the signature check (NOT recommended)
//
// The pure-Dart backend works without this; installing the prebuilt only enables the audited Rust
// backend (the default when available).

import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sr25519/src/backend/prebuilt.dart';

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }
  final verify = !args.contains('--no-verify');
  final force = args.contains('--force');

  final target = currentPrebuiltTarget();
  if (target == null) {
    stderr.writeln(
      'sr25519: no prebuilt library for this platform '
      '(${Platform.operatingSystem} / ${Abi.current()}).',
    );
    stderr.writeln(
      'Prebuilts cover desktop Linux/macOS/Windows on x64/arm64. Elsewhere, build from source: '
      '(cd rust && cargo build --release), or see BUILD.md. The pure-Dart backend works regardless.',
    );
    exitCode = 1;
    return;
  }

  final dest = prebuiltCacheLibPath(target);
  if (File(dest).existsSync() && !force) {
    stdout.writeln(
      'sr25519: ${target.libFileName} already installed at\n  $dest\n'
      'Pass --force to re-download.',
    );
    return;
  }

  try {
    stdout.writeln('sr25519: downloading ${target.assetName} (v$kSr25519LibVersion)...');
    final libBytes = await _download(target.assetUrl);

    if (verify) {
      stdout.writeln('sr25519: verifying Ed25519 signature...');
      final sigBytes = await _download(target.signatureUrl);
      final ok = await _verifySignature(libBytes, sigBytes);
      if (!ok) {
        stderr.writeln(
          'sr25519: SIGNATURE VERIFICATION FAILED for ${target.assetName} — '
          'refusing to install. (Override with --no-verify at your own risk.)',
        );
        exitCode = 1;
        return;
      }
    } else {
      stdout.writeln('sr25519: --no-verify set; skipping the signature check.');
    }

    Directory(prebuiltCacheDir(target)).createSync(recursive: true);
    // Write to a temp file then rename, so a concurrent loader never observes a partial library.
    final tmp = File('$dest.tmp');
    await tmp.writeAsBytes(libBytes, flush: true);
    tmp.renameSync(dest);

    final kib = (libBytes.length / 1024).toStringAsFixed(0);
    stdout.writeln('sr25519: installed ${target.libFileName} ($kib KiB) ->\n  $dest');
    stdout.writeln('sr25519: done. Sr25519Crypto() will now use the audited Rust backend.');
  } on Object catch (e) {
    stderr.writeln('sr25519: setup failed: $e');
    stderr.writeln(
      'Check network access and that the sr25519-v$kSr25519LibVersion release exists, '
      'or build from source: (cd rust && cargo build --release).',
    );
    exitCode = 1;
  }
}

Future<Uint8List> _download(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    client.close();
  }
}

Future<bool> _verifySignature(Uint8List message, Uint8List signatureBytes) {
  final publicKey = SimplePublicKey(_hexToBytes(kPrebuiltPublicKeyHex), type: KeyPairType.ed25519);
  final signature = Signature(signatureBytes, publicKey: publicKey);
  return Ed25519().verify(message, signature: signature);
}

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

void _printUsage() {
  stdout.writeln('''
sr25519:setup — download the signed prebuilt native library for this platform.

Usage:
  dart run sr25519:setup [--force] [--no-verify]

  --force       Re-download even if the library is already installed.
  --no-verify   Skip the Ed25519 signature check (NOT recommended).
  -h, --help    Show this help.

Installs into a per-user cache (override the root with SR25519_CACHE_DIR). Enables the audited Rust
backend; the pure-Dart backend works without it.''');
}
