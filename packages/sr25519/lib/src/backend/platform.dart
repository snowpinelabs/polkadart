import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'backend.dart';
import 'prebuilt.dart';

/// Platform-specific resolution and loading of the native `sr25519` library.
class Sr25519Platform {
  /// Library name without the `lib` prefix or platform extension.
  static const String _libraryName = 'sr25519';

  /// Load the native library for the current platform, or throw [Sr25519FfiException].
  static DynamicLibrary loadLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return _loadLinux();
    } else if (Platform.isIOS || Platform.isMacOS) {
      return _loadDarwin();
    } else if (Platform.isWindows) {
      return _loadWindows();
    }
    throw Sr25519FfiException(
      'Unsupported platform: ${Platform.operatingSystem}',
      details: 'Only Android, iOS, macOS, Linux, and Windows are supported',
    );
  }

  static DynamicLibrary _loadLinux() {
    // Prefer an explicitly resolved package/cache path; fall back to the system loader.
    final libraryPath = _resolveLibraryPath('lib$_libraryName.so');
    if (libraryPath != null) {
      return DynamicLibrary.open(libraryPath);
    }
    return DynamicLibrary.open('lib$_libraryName.so');
  }

  static DynamicLibrary _loadDarwin() {
    final libraryPath = _resolveLibraryPath('lib$_libraryName.dylib');
    if (libraryPath != null) {
      return DynamicLibrary.open(libraryPath);
    }
    try {
      return DynamicLibrary.open('lib$_libraryName.dylib');
    } catch (_) {
      // Symbols may be statically linked into the host process (e.g. iOS).
      return DynamicLibrary.process();
    }
  }

  static DynamicLibrary _loadWindows() {
    final libraryPath = _resolveLibraryPath('$_libraryName.dll');
    if (libraryPath != null) {
      return DynamicLibrary.open(libraryPath);
    }
    return DynamicLibrary.open('$_libraryName.dll');
  }

  /// Find the native library file on disk, searching the locations a pure-`dart run` consumer or a
  /// package developer would have it. Returns `null` if nothing matches (the caller then defers to
  /// the system loader).
  static String? _resolveLibraryPath(String libraryName) {
    // 1. Library installed by `dart run sr25519:setup` into the per-user cache (desktop only).
    final target = currentPrebuiltTarget();
    if (target != null) {
      final cachePath = prebuiltCacheLibPath(target);
      if (File(cachePath).existsSync()) {
        return cachePath;
      }
    }

    // 2. Local `cargo build` output, for developing against the Rust crate directly. cwd is the
    //    package/repo root during `dart test`, or the example dir when running an example.
    final cwd = Directory.current.path;
    final devPaths = <String>[
      path.join(cwd, 'rust', 'target', 'release', libraryName),
      path.join(cwd, 'rust', 'target', 'debug', libraryName),
      path.join(cwd, '..', 'rust', 'target', 'release', libraryName),
      path.join(cwd, '..', 'rust', 'target', 'debug', libraryName),
    ];
    for (final devPath in devPaths) {
      if (File(devPath).existsSync()) {
        return devPath;
      }
    }

    // 3. Conventional locations alongside the package (build_rust.sh copies into native/<platform>).
    final searchRoots = <String>[
      cwd,
      path.join(cwd, '..'),
      path.join(cwd, 'native'),
      path.join(cwd, 'lib'),
      path.join(cwd, 'build'),
    ];
    for (final root in searchRoots) {
      final direct = path.join(root, libraryName);
      if (File(direct).existsSync()) {
        return direct;
      }
      final platformPath = path.join(root, _platformSubdir(), libraryName);
      if (File(platformPath).existsSync()) {
        return platformPath;
      }
    }

    return null;
  }

  static String _platformSubdir() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    return '';
  }

  /// Whether the current platform is one sr25519 can load a native library on.
  static bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;
}
