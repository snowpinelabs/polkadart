#ifndef SR25519_H
#define SR25519_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/**
 * Returns the ABI version of this native library (see [`ABI_VERSION`]).
 */
uint32_t sr25519_abi_version(void);

/**
 * Expand a 32-byte mini-secret `seed` into a keypair.
 *
 * Writes the 32-byte public key to `out_public` and the 64-byte secret key to `out_secret`.
 * Matches `sp_core::sr25519::Pair::from_seed` (`ExpansionMode::Ed25519`).
 *
 * # Safety
 * `seed` must point to [`SEED_LEN`] readable bytes; `out_public`/`out_secret` must point to
 * [`PUBLIC_LEN`]/[`SECRET_LEN`] writable bytes.
 */
int32_t sr25519_keypair_from_seed(const uint8_t *seed, uint8_t *out_public, uint8_t *out_secret);

/**
 * Generate a fresh random keypair using the operating system CSPRNG.
 *
 * Writes the 32-byte public key to `out_public` and the 64-byte secret key to `out_secret`.
 * Equivalent to `sp_core::sr25519::Pair::generate` (random mini-secret, `ExpansionMode::Ed25519`).
 *
 * # Safety
 * `out_public`/`out_secret` must point to [`PUBLIC_LEN`]/[`SECRET_LEN`] writable bytes.
 */
int32_t sr25519_generate(uint8_t *out_public, uint8_t *out_secret);

/**
 * Derive the 32-byte public key from a 64-byte secret key.
 *
 * # Safety
 * `secret` must point to [`SECRET_LEN`] readable bytes; `out_public` to [`PUBLIC_LEN`] writable
 * bytes.
 */
int32_t sr25519_public_from_secret(const uint8_t *secret, uint8_t *out_public);

/**
 * Sign `msg` (of `msg_len` bytes) with a 64-byte secret key, using the `b"substrate"` context.
 *
 * Writes the 64-byte signature to `out_sig`. Matches `sp_core::sr25519::Pair::sign`. The signature
 * is randomized (a fresh nonce per call), so repeated calls produce different — all valid — bytes.
 *
 * # Safety
 * `secret` must point to [`SECRET_LEN`] readable bytes; `msg` to `msg_len` readable bytes (may be
 * null only when `msg_len == 0`); `out_sig` to [`SIG_LEN`] writable bytes.
 */
int32_t sr25519_sign(const uint8_t *secret,
                     const uint8_t *msg,
                     uintptr_t msg_len,
                     uint8_t *out_sig);

/**
 * Verify a 64-byte signature against a 32-byte public key and `msg` (of `msg_len` bytes).
 *
 * Returns `1` if the signature is valid, `0` if it is well-formed but does not verify, and a
 * negative [`ERR_NULL`]/[`ERR_PARSE`] code if an argument is null or malformed. Matches
 * `sp_core::sr25519::Pair::verify` (`verify_simple` with the `b"substrate"` context).
 *
 * # Safety
 * `public` must point to [`PUBLIC_LEN`] readable bytes; `sig` to [`SIG_LEN`] readable bytes; `msg`
 * to `msg_len` readable bytes (may be null only when `msg_len == 0`).
 */
int32_t sr25519_verify(const uint8_t *public_,
                       const uint8_t *sig,
                       const uint8_t *msg,
                       uintptr_t msg_len);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  /* SR25519_H */
