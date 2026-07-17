# ADR-0011 · Authentication is ADR-036 challenge-response; the address is the identity

- **Status:** accepted
- **Date:** 2026-05-01
- **Deciders:** project owner

## Context and problem statement

Every committee member, coordinator, and validator must prove control of a Cosmos operator key to the coordination server —
from a browser or a script — without the server holding or pre-registering keys. How is identity proven?

## Decision

Authenticate by **signing a server challenge with the wallet's `signArbitrary` (Cosmos SDK ADR-036
arbitrary-message signing)**:

- `POST /auth/challenge {operator_address}` → a short-lived nonce challenge (5-min TTL).
- The client signs a canonical-JSON payload (field order `challenge → nonce → operator_address →
  timestamp`) with its secp256k1 wallet key via ADR-036 amino sign bytes.
- `POST /auth/verify` → the server verifies and returns a short-lived (1 h) Ed25519 JWT bearer token.
- **The bech32 address is the identity.** The server holds and pre-registers *no* pubkeys; the caller
  supplies its compressed secp256k1 pubkey per request (`pubkey_b64`), and the server proves it derives
  to the claimed address via `RIPEMD160(SHA256(pubkey))` bech32. The pubkey is a per-request verification
  hint bound to the address, not a stored credential.

## Consequences

- **Good:** keys never leave the client; the server stores no key material; any wallet that does ADR-036
  works (the interchain-kit web client and the smoke signer today; a future CLI similarly).
- **Good:** one uniform handshake for all roles.
- **Contract:** every client MUST produce byte-identical ADR-036 amino sign bytes (`BuildADR036AminoBytes`)
  and the same canonical signing payload — a cross-component wire contract.
- **Trade-off:** ADR-036 amino sign-byte reconstruction is fiddly (the same class of problem as the
  gentx sign-bytes notes in seedward-libs).

## Alternatives considered

- **Pre-registered pubkeys** — rejected: the server would hold a key registry; deriving the address from a
  per-request pubkey needs none.

## Related

- Reference: chaincoord [concepts/roles.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/roles/) (Authentication). Identity a join request carries:
  [ADR-0013](0013-submitter-validator-identity-split.md). Nonce/challenge/JWT mechanics: chaincoord [decisions/](https://ny4rl4th0t3p.github.io/seedward-chaincoord/decisions/).
  **Refined by [ADR-0024](0024-hrp-independent-account-identity.md)** — the identity is the HRP-independent account.
