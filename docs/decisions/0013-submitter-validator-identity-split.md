# ADR-0013 · A join request has two identities: hot submitter, cold validator operator

- **Status:** accepted
- **Date:** 2026-06-29
- **Deciders:** project owner

## Context and problem statement

When a validator applies to a launch, who "is" the applicant — the key that signed the submission, or the
validator's operator account? Early code conflated them, which broke when an authorized uploader submits
on a validator's behalf, and mis-keyed voting power / dedup / caps.

## Decision

A join request carries **two distinct addresses**:

- **`submitter_address`** — the hot key that signed the submission. The provenance / auth / membership /
  grouping key.
- **`operator_address`** — the cold validator / self-delegator account, **derived from the gentx's
  signer** during validation (`RIPEMD160(SHA256(pubkey))`), **not self-declared**, and checked against the
  gentx's `validator_address`.

They may be identical or different. Voting power, per-validator dedup, and the per-submitter cap were
re-keyed on this split. The API surfaces both: `joinRequestJSON.submitter_address` (a security/group key,
not cosmetic) and `GET /launch/{id}/join/grouped` (submitter-grouped aggregates for approval review).

## Consequences

- **Good:** an authorized operator can submit for a validator without impersonating it; the *validator*
  identity is cryptographically derived, not trusted from the request body.
- **Good:** approval review groups by submitter (spot a submitter flooding requests) while dedup and
  voting power key on the validator.
- **Trade-off:** two address fields to reason about; the API and web approval UI must show both.

## Alternatives considered

- **Single address (submitter = operator)** — rejected: forbids delegated submission and lets a request
  self-declare its validator identity.

## Related

- Reference: chaincoord [concepts/roles.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/roles/) (operator-address derivation). Auth:
  [ADR-0011](0011-adr036-challenge-response-auth.md). Membership: [ADR-0012](0012-private-always-membership-visibility.md).
  The hot (submitter) side is HRP-independent: [ADR-0024](0024-hrp-independent-account-identity.md).
