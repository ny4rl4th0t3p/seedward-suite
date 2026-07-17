# ADR-0025 · Cancellation is stage-dependent (hybrid governance)

- **Status:** accepted
- **Date:** 2026-07-16
- **Deciders:** project owner

## Context and problem statement

[ADR-0010](0010-m-of-n-committee-proposal-governance.md) carved `cancel` out of the M-of-N proposal model
as a direct action. In practice this made `CancelLaunch` the committee **lead's** only unilateral,
irreversible power — and it was allowed from *every* non-terminal stage. So a single lead could destroy a
fully committee-approved, readiness-confirmed launch (`WINDOW_CLOSED`/`GENESIS_READY`) with no vote and no
undo, unlike every other post-DRAFT committee action. The **cost** of a cancel rises sharply with stage
(from scrapping the lead's own setup, to wiping validators who stood up nodes and confirmed readiness); the
**authority** to do it did not. How should cancellation be authorized so authority tracks cost?

## Decision

Cancellation is **hybrid**, split at the `PUBLISHED│WINDOW_OPEN` boundary — the point where external
parties first commit gentxs:

- **`DRAFT` / `PUBLISHED`** — the **lead** may cancel directly (`POST /launch/:id/cancel`), no proposal. No
  validators have committed, so a unilateral scrap is harmless. Any committee member may instead take the
  proposal path below.
- **`WINDOW_OPEN` / `WINDOW_CLOSED` / `GENESIS_READY`** — the direct endpoint returns `409`; cancellation
  requires an **M-of-N `CANCEL_LAUNCH` committee proposal** (a proposal action any committee member may
  raise). Cancelling from `GENESIS_READY` invalidates the readiness confirmations validators submitted.
- **`LAUNCHED` / `CANCELLED`** — terminal; not cancellable.

The `CANCEL_LAUNCH` proposal is valid from **any** non-terminal state, so a non-lead committee member can
always initiate a *governed* cancel — even early, when the lead's direct shortcut also exists. The lead's
direct path is a convenience, not the only way.

## Consequences

- **Good:** a single seat can no longer irreversibly destroy a committee-approved, readiness-confirmed
  launch. High-stakes cancels carry the full M-of-N raise/sign/execute signed audit trail (closing an
  audit-coverage gap).
- **Good:** the lead's only remaining unilateral, irreversible power is the harmless `DRAFT`/`PUBLISHED`
  scrap — reinforcing the "thin lead" model (the lead is `Members[0]`, not a separate authority).
- **Good:** the committee is never at the mercy of an absent or adversarial lead — the proposal path is
  always open, including in the early stages.
- **Trade-off:** two cancel paths coexist in `DRAFT`/`PUBLISHED` (direct + proposal) instead of one.
- **Refines [ADR-0010](0010-m-of-n-committee-proposal-governance.md):** `cancel` is no longer
  unconditionally "not a proposal" — past `PUBLISHED` it *is* an M-of-N proposal like every other
  consequential mutation.

## Alternatives considered

- **Keep cancel fully direct and lead-only from any state (ADR-0010's original carve-out)** — rejected: lets
  one seat destroy a multi-party commitment with no vote and no undo; authority does not track cost.
- **Make every cancel an M-of-N proposal** — rejected: needless ceremony for a `DRAFT`/`PUBLISHED` scrap
  where nothing external has been committed; the lead keeps its direct shortcut there.
- **Boundary at `WINDOW_OPEN│WINDOW_CLOSED`** — rejected: `WINDOW_OPEN` already has in-flight validator
  join requests and gentxs, so external commitment starts there, not at window close.

## Related

- Amends [ADR-0010](0010-m-of-n-committee-proposal-governance.md) (M-of-N committee proposals) on cancel.
- [ADR-0009](0009-launch-lifecycle-state-machine.md) · the lifecycle states this splits on.
- Implementation: the `CANCEL_LAUNCH` proposal action + the direct `/cancel` endpoint (chaincoord [concepts/](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/overview/)).
