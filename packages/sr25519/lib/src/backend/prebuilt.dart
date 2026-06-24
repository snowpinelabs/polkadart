// Prebuilt-binary distribution metadata shared by the loader (platform.dart) and the installer
// (bin/setup.dart). `dart run sr25519:setup` downloads the signed native library for the current
// platform from the GitHub Release and writes it to [prebuiltCacheLibPath]; the loader then finds it
// there without the consumer needing a Rust toolchain.
//
// Only DESKTOP (pure-`dart run`) targets ship a prebuilt today — Linux/macOS/Windows on x64+arm64.
// Mobile (Android/iOS) libraries are embedded in the host app build, not downloaded, so they are
// intentionally absent from [currentPrebuiltTarget]; add them here once that pipeline exists.

import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

/// Version of the prebuilt native library this Dart package expects.
///
/// MUST match `version:` in pubspec.yaml: the installer downloads the signed assets from the
/// `sr25519-v$kSr25519LibVersion` GitHub Release, and the cache is keyed by this version so upgrades
/// re-download rather than load a stale library.
const String kSr25519LibVersion = '0.7.3';

/// Base URL of the GitHub Release that hosts the signed prebuilt libraries.
///
/// The polkadart repository holds many packages, so the sr25519 prebuilts live on a package-scoped
/// tag (`sr25519-v<version>`) rather than a bare `v<version>` tag.
const String kPrebuiltUrlPrefix =
    'https://github.com/snowpinelabs/polkadart/releases/download/sr25519-v$kSr25519LibVersion/';

/// Ed25519 public key (hex) whose private half signs the prebuilt binaries in CI.
///
/// The installer verifies each downloaded library against this key before installing it. Rotate with
/// `dart run tool/gen_key.dart`, paste the public hex here, and set the private hex as the
/// `SR25519_SIGNING_KEY` repository secret consumed by `.github/workflows/release_sr25519.yml`.
const String kPrebuiltPublicKeyHex =
    '775dd953e4f4fab54cd89766d20689717350e8c860255f01370a4abc626f0823';

/// A native target sr25519 publishes a prebuilt library for.
class PrebuiltTarget {
  const PrebuiltTarget(this.triple, this.libFileName);

  /// Rust target triple, e.g. `aarch64-apple-darwin`.
  final String triple;

  /// Platform library file name the loader opens, e.g. `libsr25519.dylib`.
  final String libFileName;

  /// Release asset name carrying the library, e.g. `sr25519-aarch64-apple-darwin.dylib`.
  /// The triple keeps it unique across the two same-extension Apple/Windows arches.
  String get assetName {
    final ext = libFileName.substring(libFileName.lastIndexOf('.'));
    return 'sr25519-$triple$ext';
  }

  /// Detached Ed25519 signature asset name (`<assetName>.sig`).
  String get signatureAssetName => '$assetName.sig';

  /// Absolute URL of the library asset on the GitHub Release.
  Uri get assetUrl => Uri.parse('$kPrebuiltUrlPrefix$assetName');

  /// Absolute URL of the detached signature asset.
  Uri get signatureUrl => Uri.parse('$kPrebuiltUrlPrefix$signatureAssetName');
}

/// The prebuilt target for the current process, or `null` when this platform/arch has no prebuilt
/// (e.g. iOS/Android — those are app-embedded, not `dart run` targets — and an unknown desktop arch).
PrebuiltTarget? currentPrebuiltTarget() {
  switch (Abi.current()) {
    case Abi.macosArm64:
      return const PrebuiltTarget('aarch64-apple-darwin', 'libsr25519.dylib');
    case Abi.macosX64:
      return const PrebuiltTarget('x86_64-apple-darwin', 'libsr25519.dylib');
    case Abi.linuxX64:
      return const PrebuiltTarget('x86_64-unknown-linux-gnu', 'libsr25519.so');
    case Abi.linuxArm64:
      return const PrebuiltTarget('aarch64-unknown-linux-gnu', 'libsr25519.so');
    case Abi.windowsX64:
      return const PrebuiltTarget('x86_64-pc-windows-msvc', 'sr25519.dll');
    case Abi.windowsArm64:
      return const PrebuiltTarget('aarch64-pc-windows-msvc', 'sr25519.dll');
    default:
      return null;
  }
}

/// Absolute path where `dart run sr25519:setup` installs the prebuilt library for [target] and where
/// the loader looks for it. Override the root directory with `SR25519_CACHE_DIR`.
String prebuiltCacheLibPath(PrebuiltTarget target) =>
    _join([prebuiltCacheDir(target), target.libFileName]);

/// Directory holding the installed library for [target] (the parent of [prebuiltCacheLibPath]).
String prebuiltCacheDir(PrebuiltTarget target) =>
    _join([_cacheRoot(), 'sr25519', 'v$kSr25519LibVersion', target.triple]);

String _cacheRoot() {
  final env = Platform.environment;
  final override = env['SR25519_CACHE_DIR'];
  if (override != null && override.isNotEmpty) return override;
  if (Platform.isWindows) {
    final local = env['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) return local;
    return _join([env['USERPROFILE'] ?? '.', 'AppData', 'Local']);
  }
  final home = env['HOME'] ?? '.';
  if (Platform.isMacOS) return _join([home, 'Library', 'Caches']);
  final xdg = env['XDG_CACHE_HOME'];
  if (xdg != null && xdg.isNotEmpty) return xdg;
  return _join([home, '.cache']);
}

// dart:io accepts forward slashes on every supported platform, so a plain '/' join avoids a
// dependency on package:path for the handful of paths we build.
String _join(List<String> parts) => parts.join('/');
