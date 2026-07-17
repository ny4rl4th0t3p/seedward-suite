# ADR-0001 · Gentx validation is a pure single-gentx library; cross-request checks live in coordd

- **Status:** accepted
- **Date:** 2026-06-10
- **Deciders:** project owner

## Context and problem statement

`gentxvalidate` (in seedward-libs) validates a submitted gentx against a launch's declared parameters.
Some desirable checks are not properties of a *single* gentx but of the *set* — most notably
**consensus-pubkey uniqueness** (no two validators may share a consensus key). Where should such
cross-request checks live: in the shared validation library, or in coordd?

## Decision

**The library validates one gentx in isolation and nothing else. Cross-request constraints are coordd's.**

- `gentxvalidate` takes one gentx + `Params` and returns per-invariant `Result`s. It holds no state and
  sees no other submissions.
- **Consensus-pubkey uniqueness is enforced by a DB unique index in coordd's repository layer** — the
  only race-free enforcement point. A snapshot "is this key already used?" check is check-then-insert
  racy and redundant with the constraint the database needs anyway.

## Consequences

- **Good:** the library is pure, stateless, and trivially embeddable (server, CLI, browser WASM) — no
  database or request context required. This is the precondition for [ADR-0002](0002-client-side-gentx-validation-wasm.md).
- **Good:** uniqueness is enforced exactly once, race-free, at the storage boundary that owns it.
- **Trade-off:** coordd must own its uniqueness constraint; the library is *not* the one place "all gentx
  validation" lives. Accepted — the two concerns are genuinely different (single-artifact vs among-set).

## Alternatives considered

- **Dup-pubkey check in the library over a caller-supplied set** — rejected: pushes state / among-set
  context into a pure validator, and is still racy without the DB constraint, so it would be redundant.

## Related

- seedward-libs `gentxvalidate` (the pure validator); repo-internal notes in [seedward-libs/docs/decisions.md](https://github.com/ny4rl4th0t3p/seedward-libs/blob/main/docs/decisions.md).