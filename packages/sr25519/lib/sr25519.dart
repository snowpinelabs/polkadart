library sr25519;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:merlin/merlin.dart' as merlin;
import 'package:ristretto255/ristretto255.dart' as r255;
import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:substrate_bip39/substrate_bip39.dart';

// Dual-backend API: pick the audited Rust (schnorrkel / sp_core::sr25519-compatible) backend by
// default, falling back to the pure-Dart implementation below when the native library is absent.
// See `Sr25519Crypto`. These are regular libraries (not `part`s) so the FFI installer
// (`bin/setup.dart`) and tooling can import the prebuilt metadata directly.
export 'src/backend/backend.dart';
export 'src/backend/dart_backend.dart' show DartSr25519Backend, Sr25519Sizes;
export 'src/backend/rust_backend.dart' show RustSr25519Backend;
export 'src/backend/sr25519_crypto.dart';

part 'src/bip39.dart';
part 'src/derivable_key.dart';
part 'src/extended_key.dart';
part 'src/signature.dart';
part 'src/public_key.dart';
part 'src/secret_key.dart';
part 'src/utilities.dart';
part 'src/sr25519.dart';
part 'src/keypair.dart';
part 'src/mini_secret_key.dart';
part 'src/batch.dart';
part 'src/vrf_in_out.dart';
part 'src/vrf_output.dart';
part 'src/vrf_proof.dart';
