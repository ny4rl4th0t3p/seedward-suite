# ADR-0009 · Launch lifecycle is a guarded state machine

- **Status:** accepted
- **Date:** 2026-04-10
- **Deciders:** project owner

## Context and problem statement

A chain launch moves through distinct phases — draft, application window, genesis assembly, launch.
Committee members, validators, the rehearsal service, and the web UI all need a single, unambiguous notion of
"where is this launch." How should that progression be modelled?

## Decision

The `Launch` aggregate is a **state machine** with seven states, each entered by exactly one *guarded*
domain method:

- `DRAFT` → `PUBLISHED` (`Publish`, requires the initial genesis hash) → `WINDOW_OPEN` (`OpenWindow`) →
  `WINDOW_CLOSED` (`CloseWindow`, gated on `min_validator_count` + a BFT ≥ 1/3 dominant-power check) →
  `GENESIS_READY` (`PublishGenesis`, requires the final genesis hash) → `LAUNCHED` (terminal).
- One **back-edge**: `GENESIS_READY → WINDOW_CLOSED` (`ReopenForRevision`, clears the final genesis) so a
  finalized genesis can be revised.
- `CANCELED` is terminal, reachable from any non-terminal state.

Transitions are the **only** way `status` changes; each rejects an out-of-order call with a sentinel error.

## Consequences

- **Good:** `status` is a reliable coordination signal the whole suite keys on — the bridge serves
  rehearsal input by status, the rehearsal gate acts on the `WINDOW_CLOSED → GENESIS_READY` transition,
  the web renders the phase. A launch cannot skip a guard.
- **Good:** the single revision back-edge is explicit, not an ad-hoc status write.
- **Trade-off:** adding a phase means a new guarded transition, not a free-form status set — deliberate
  rigidity.
- The persisted/wire value is `"CANCELED"` (one L) even though the Go identifier is `StatusCancelled`.

## Alternatives considered

- **Free-form status field** — rejected: lets code write any status, losing the guarantee that guards ran.
- **Separate aggregate per phase** — rejected: a launch is one entity with one identity across its life.

## Related

- Reference: chaincoord [concepts/lifecycle.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/lifecycle/). Who authorizes the transitions:
  [ADR-0010](0010-m-of-n-committee-proposal-governance.md). The `WINDOW_CLOSED → GENESIS_READY` gate +
  genesis-consistency guards: [ADR-0003](0003-rehearsal-optional-bolt-on.md).
