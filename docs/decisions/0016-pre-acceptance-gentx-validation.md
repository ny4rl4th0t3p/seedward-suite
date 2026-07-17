# ADR-0016 · Gentxs are validated at submission with the shared library, server-grade

- **Status:** accepted
- **Date:** 2026-06-18
- **Deciders:** project owner

## Context and problem statement

A validator submits a gentx to join a launch. coordd once did inline, partial gentx checks in the domain.
Should coordd keep its own validation, and how thorough should acceptance be?

## Decision

**coordd validates every submitted gentx *before storing it*, using the shared
`seedward-libs/gentxvalidate.RunAll` server-side** (via a `ports.GentxValidator` port + an
`infrastructure/gentxvalidation` adapter); the former inline domain checks are deleted (`joinrequest.New`
is now a pure constructor).

- **Server-grade (`RunAll`, not `RunLight`):** the full invariant set, including the **cryptographic
  signature** check and the **derived operator address** — one shared implementation with the browser WASM
  (and a future CLI), so no drift (see [ADR-0001](0001-single-gentx-validator-boundary.md) /
  [ADR-0002](0002-client-side-gentx-validation-wasm.md)).
- On success the adapter also extracts the consensus pubkey and the derived operator/validator address
  (used for dedup + committee vetting — the ADR-0013 cold identity).
- On failure it returns a **structured 400** carrying the per-invariant `[]Result` (`GentxInvalidError`) —
  the Workstream-C response the web renders inline.
- The self-delegation floor is a launch-type-conditional service gate (mainnet / incentivized /
  permissioned).

## Consequences

- **Good:** a bad gentx is rejected at the door with a precise, per-invariant reason; coordd trusts the
  *derived* validator identity, not the request body.
- **Good:** zero validation drift between coordd and the browser (and a future CLI) — one library.
- **Trade-off:** coordd depends on seedward-libs and does real crypto at submission (bounded).

## Alternatives considered

- **Inline / duplicated checks in coordd** — removed: forks the rules from the source of truth and was
  only partial.
- **Client-only (browser) validation** — insufficient: advisory only; the server must be authoritative
  (the browser path is [ADR-0002](0002-client-side-gentx-validation-wasm.md)).

## Related

- The shared validator: [ADR-0001](0001-single-gentx-validator-boundary.md),
  [ADR-0002](0002-client-side-gentx-validation-wasm.md). The two identities it derives:
  [ADR-0013](0013-submitter-validator-identity-split.md). Reference: chaincoord [concepts/validation.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/validation/).
