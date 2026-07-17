# ADR-0003 · Rehearsal is an optional bolt-on; coordd runs standalone

- **Status:** accepted
- **Date:** 2026-07-07
- **Deciders:** project owner

## Context and problem statement

The rehearsal service (seedward-rehearsal) validates that a launch's approved gentxs + allocation files
actually boot and reconcile before genesis is finalized. It would be tempting to make coordd depend on
it. But `coordd` is the coordination server operators must be able to run on its own — many launches
will never stand up a rehearsal service. Should rehearsal be a hard dependency of the
genesis-finalization flow?

## Decision

**No. `coordd` runs fully standalone; rehearsal is an optional bolt-on.**

- The rehearsal gate (`COORD_REHEARSAL_GATE`) defaults to `off`; in `off` mode coordd never consults a
  rehearsal fact.
- The bridge is a **one-way write-back** — `rehearsald` posts a signed result fact to coordd; coordd
  never calls the rehearsal service.
- Making rehearsal **required** is an explicit, per-deployment opt-in, and coordd **fails fast at
  startup** if `required` is set without a rehearsal service configured.

## Consequences

- **Good:** a coordd with no rehearsal service is a complete, working product — no accidental coupling.
- **Good:** the gate is a *policy knob* (`off` / `advisory` / `required`), not an architectural
  dependency.
- **Trade-off:** operators who want mandatory rehearsal must opt in and run `rehearsald` themselves.
- **Invariant, independent of this gate:** coordd *always* enforces that a published genesis matches the
  approved set it was built from — a correctness guarantee, not a rehearsal feature (a future ADR).

## Alternatives considered

- **Rehearsal required by default** — rejected: forces every operator to run a second service and
  couples the core flow to an optional component.
- **coordd calls rehearsald synchronously during finalization** — rejected: inverts the dependency,
  makes coordd's availability depend on the rehearsal service, and complicates the trust model (coordd
  would trust a live response rather than a signed, verifiable fact).

## Related

- Wire contract: [Bridge contract](../reference/bridge-contract.md).
- [Architecture overview](../architecture/overview.md).