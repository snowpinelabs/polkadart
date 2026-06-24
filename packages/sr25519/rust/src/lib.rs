//! C-ABI FFI bindings for sr25519, backed by the audited [`schnorrkel`] crate.
//!
//! These are the exact primitives `sp_core::sr25519` is built on, called the same way, so every
//! output here is byte-identical to `sp_core::sr25519`:
//!
//! * key generation expands a 32-byte mini-secret with [`ExpansionMode::Ed25519`]
//!   (`sp_core::sr25519::Pair::from_seed`);
//! * signing uses the `b"substrate"` signing context (`sp_core::sr25519::SIGNING_CTX`) via
//!   `sign_simple` / `verify_simple`;
//! * serialized keys and signatures use schnorrkel's canonical `to_bytes`/`from_bytes` encodings
//!   (the signature carries schnorrkel's high-bit marker in byte 63).
//!
//! Memory model: every function takes caller-allocated input/output buffers and copies into them.
//! Nothing is heap-allocated on the Rust side and handed back, so there is no companion `free`
//! function and no ownership to track across the boundary.

use core::ptr;
use core::slice;

use schnorrkel::{
    ExpansionMode, MiniSecretKey, PublicKey, SecretKey, Signature,
};

/// Substrate signing context. Identical to `sp_core::sr25519::SIGNING_CTX`.
const SIGNING_CTX: &[u8] = b"substrate";

/// Length of a mini-secret seed, in bytes.
const SEED_LEN: usize = 32;
/// Length of a serialized public key, in bytes.
const PUBLIC_LEN: usize = 32;
/// Length of a serialized secret key (`key || nonce`), in bytes.
const SECRET_LEN: usize = 64;
/// Length of a serialized signature, in bytes.
const SIG_LEN: usize = 64;

/// Operation succeeded.
const OK: i32 = 0;
/// A required pointer argument was null.
const ERR_NULL: i32 = -1;
/// An input buffer did not parse into a valid key/signature.
const ERR_PARSE: i32 = -2;

/// ABI version of this library. Bump on any breaking change to a function signature or buffer
/// layout below. The Dart loader reads this to confirm it loaded a compatible binary.
const ABI_VERSION: u32 = 1;

/// Returns the ABI version of this native library (see [`ABI_VERSION`]).
#[no_mangle]
pub extern "C" fn sr25519_abi_version() -> u32 {
    ABI_VERSION
}

/// Expand a 32-byte mini-secret `seed` into a keypair.
///
/// Writes the 32-byte public key to `out_public` and the 64-byte secret key to `out_secret`.
/// Matches `sp_core::sr25519::Pair::from_seed` (`ExpansionMode::Ed25519`).
///
/// # Safety
/// `seed` must point to [`SEED_LEN`] readable bytes; `out_public`/`out_secret` must point to
/// [`PUBLIC_LEN`]/[`SECRET_LEN`] writable bytes.
#[no_mangle]
pub unsafe extern "C" fn sr25519_keypair_from_seed(
    seed: *const u8,
    out_public: *mut u8,
    out_secret: *mut u8,
) -> i32 {
    if seed.is_null() || out_public.is_null() || out_secret.is_null() {
        return ERR_NULL;
    }
    let seed = slice::from_raw_parts(seed, SEED_LEN);
    let mini = match MiniSecretKey::from_bytes(seed) {
        Ok(m) => m,
        Err(_) => return ERR_PARSE,
    };
    let keypair = mini.expand_to_keypair(ExpansionMode::Ed25519);
    write(out_public, &keypair.public.to_bytes());
    write(out_secret, &keypair.secret.to_bytes());
    OK
}

/// Generate a fresh random keypair using the operating system CSPRNG.
///
/// Writes the 32-byte public key to `out_public` and the 64-byte secret key to `out_secret`.
/// Equivalent to `sp_core::sr25519::Pair::generate` (random mini-secret, `ExpansionMode::Ed25519`).
///
/// # Safety
/// `out_public`/`out_secret` must point to [`PUBLIC_LEN`]/[`SECRET_LEN`] writable bytes.
#[no_mangle]
pub unsafe extern "C" fn sr25519_generate(out_public: *mut u8, out_secret: *mut u8) -> i32 {
    if out_public.is_null() || out_secret.is_null() {
        return ERR_NULL;
    }
    let keypair = MiniSecretKey::generate().expand_to_keypair(ExpansionMode::Ed25519);
    write(out_public, &keypair.public.to_bytes());
    write(out_secret, &keypair.secret.to_bytes());
    OK
}

/// Derive the 32-byte public key from a 64-byte secret key.
///
/// # Safety
/// `secret` must point to [`SECRET_LEN`] readable bytes; `out_public` to [`PUBLIC_LEN`] writable
/// bytes.
#[no_mangle]
pub unsafe extern "C" fn sr25519_public_from_secret(
    secret: *const u8,
    out_public: *mut u8,
) -> i32 {
    if secret.is_null() || out_public.is_null() {
        return ERR_NULL;
    }
    let secret = match SecretKey::from_bytes(slice::from_raw_parts(secret, SECRET_LEN)) {
        Ok(s) => s,
        Err(_) => return ERR_PARSE,
    };
    write(out_public, &secret.to_public().to_bytes());
    OK
}

/// Sign `msg` (of `msg_len` bytes) with a 64-byte secret key, using the `b"substrate"` context.
///
/// Writes the 64-byte signature to `out_sig`. Matches `sp_core::sr25519::Pair::sign`. The signature
/// is randomized (a fresh nonce per call), so repeated calls produce different — all valid — bytes.
///
/// # Safety
/// `secret` must point to [`SECRET_LEN`] readable bytes; `msg` to `msg_len` readable bytes (may be
/// null only when `msg_len == 0`); `out_sig` to [`SIG_LEN`] writable bytes.
#[no_mangle]
pub unsafe extern "C" fn sr25519_sign(
    secret: *const u8,
    msg: *const u8,
    msg_len: usize,
    out_sig: *mut u8,
) -> i32 {
    if secret.is_null() || out_sig.is_null() || (msg.is_null() && msg_len != 0) {
        return ERR_NULL;
    }
    let secret = match SecretKey::from_bytes(slice::from_raw_parts(secret, SECRET_LEN)) {
        Ok(s) => s,
        Err(_) => return ERR_PARSE,
    };
    let message = if msg_len == 0 {
        &[][..]
    } else {
        slice::from_raw_parts(msg, msg_len)
    };
    let public = secret.to_public();
    let signature = secret.sign_simple(SIGNING_CTX, message, &public);
    write(out_sig, &signature.to_bytes());
    OK
}

/// Verify a 64-byte signature against a 32-byte public key and `msg` (of `msg_len` bytes).
///
/// Returns `1` if the signature is valid, `0` if it is well-formed but does not verify, and a
/// negative [`ERR_NULL`]/[`ERR_PARSE`] code if an argument is null or malformed. Matches
/// `sp_core::sr25519::Pair::verify` (`verify_simple` with the `b"substrate"` context).
///
/// # Safety
/// `public` must point to [`PUBLIC_LEN`] readable bytes; `sig` to [`SIG_LEN`] readable bytes; `msg`
/// to `msg_len` readable bytes (may be null only when `msg_len == 0`).
#[no_mangle]
pub unsafe extern "C" fn sr25519_verify(
    public: *const u8,
    sig: *const u8,
    msg: *const u8,
    msg_len: usize,
) -> i32 {
    if public.is_null() || sig.is_null() || (msg.is_null() && msg_len != 0) {
        return ERR_NULL;
    }
    let public = match PublicKey::from_bytes(slice::from_raw_parts(public, PUBLIC_LEN)) {
        Ok(p) => p,
        Err(_) => return ERR_PARSE,
    };
    let signature = match Signature::from_bytes(slice::from_raw_parts(sig, SIG_LEN)) {
        Ok(s) => s,
        Err(_) => return ERR_PARSE,
    };
    let message = if msg_len == 0 {
        &[][..]
    } else {
        slice::from_raw_parts(msg, msg_len)
    };
    match public.verify_simple(SIGNING_CTX, message, &signature) {
        Ok(()) => 1,
        Err(_) => 0,
    }
}

/// Copy `src` into the caller-provided `dst` buffer, which must have room for `src.len()` bytes.
#[inline]
unsafe fn write(dst: *mut u8, src: &[u8]) {
    ptr::copy_nonoverlapping(src.as_ptr(), dst, src.len());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sign_then_verify_roundtrips() {
        let mut public = [0u8; PUBLIC_LEN];
        let mut secret = [0u8; SECRET_LEN];
        let seed = [7u8; SEED_LEN];
        unsafe {
            assert_eq!(
                sr25519_keypair_from_seed(seed.as_ptr(), public.as_mut_ptr(), secret.as_mut_ptr()),
                OK
            );
            let msg = b"hello sr25519";
            let mut sig = [0u8; SIG_LEN];
            assert_eq!(
                sr25519_sign(secret.as_ptr(), msg.as_ptr(), msg.len(), sig.as_mut_ptr()),
                OK
            );
            assert_eq!(
                sr25519_verify(public.as_ptr(), sig.as_ptr(), msg.as_ptr(), msg.len()),
                1
            );
            // Tampered message fails to verify.
            let bad = b"hello sr25518";
            assert_eq!(
                sr25519_verify(public.as_ptr(), sig.as_ptr(), bad.as_ptr(), bad.len()),
                0
            );
        }
    }

    #[test]
    fn seed_expansion_is_deterministic() {
        let seed = [3u8; SEED_LEN];
        let (mut p1, mut s1) = ([0u8; PUBLIC_LEN], [0u8; SECRET_LEN]);
        let (mut p2, mut s2) = ([0u8; PUBLIC_LEN], [0u8; SECRET_LEN]);
        unsafe {
            sr25519_keypair_from_seed(seed.as_ptr(), p1.as_mut_ptr(), s1.as_mut_ptr());
            sr25519_keypair_from_seed(seed.as_ptr(), p2.as_mut_ptr(), s2.as_mut_ptr());
        }
        assert_eq!(p1, p2);
        assert_eq!(s1, s2);
    }
}
