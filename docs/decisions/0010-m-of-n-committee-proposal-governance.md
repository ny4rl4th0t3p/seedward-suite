# ADR-0010 · Governance actions are M-of-N committee proposals

- **Status:** accepted — amended on cancel by [ADR-0025](0025-cancel-governance-hybrid.md)
- **Date:** 2026-04-10
- **Deciders:** project owner

## Context and problem statement

A launch is governed by an M-of-N committee. Mutating actions — approve a validator, publish
genesis, change the committee — must not be unilaterally executable by one committee member. How are these
actions authorized?

## Decision

Every governance action is a **`Proposal` aggregate** decided by **M-of-N** committee vote:

- The proposer implicitly **SIGNs** at creation; other members **SIGN** or **VETO**.
- A single **VETO** kills the proposal immediately (`VETOED`).
- When the SIGN count reaches the threshold **M**, the proposal is `EXECUTED` and its side effects apply.
- **Auto-execute-on-quorum:** the quorum check runs at *raise*, so a 1-of-N committee executes on raise —
  a solo committee member still goes "through governance," it just meets quorum immediately.
- TTL elapse → `EXPIRED`. Four statuses: `PENDING_SIGNATURES`, `EXECUTED`, `VETOED`, `EXPIRED`.
- The proposal decides its own execution (counts signatures vs M); the application layer applies the side
  effects to the affected aggregates in **one transaction** and dispatches events **after commit**.

## Consequences

- **Good:** no committee member acts unilaterally on an M>1 committee; the threshold is the trust knob.
- **Good:** one uniform mechanism for every mutation — validator approval, genesis publication, committee
  changes — so the web surfaces "proposals" generically and the audit log is one stream.
- **Good:** single-veto-kill makes objection cheap and decisive.
- **Trade-off:** a few operational actions are deliberately **not** proposals (opening the window,
  canceling) — the boundary is recorded in chaincoord's own decisions.

## Alternatives considered

- **Lead-does-everything** — rejected: reintroduces the single point of unilateral control
  the committee exists to prevent.
- **Off-chain multisig** — rejected: the coordination server already holds the state; on-server M-of-N
  keeps the whole decision trail in one tamper-evident audit log.

## Related

- **Amended by [ADR-0025](0025-cancel-governance-hybrid.md)** — the "operational actions deliberately not
  proposals … (canceling)" carve-out above is superseded on cancel: past `PUBLISHED`, cancellation *is* an
  M-of-N `CANCEL_LAUNCH` proposal. This ADR's body is kept as the original snapshot.
- Reference: chaincoord [concepts/proposals.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/proposals/). The lifecycle it drives:
  [ADR-0009](0009-launch-lifecycle-state-machine.md). chaincoord-internal specifics (action types, TTL,
  sentinels, which actions bypass proposals) live in chaincoord's own [decisions/](https://ny4rl4th0t3p.github.io/seedward-chaincoord/decisions/).
