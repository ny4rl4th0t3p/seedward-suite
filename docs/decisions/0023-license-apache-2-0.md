# ADR-0023 · The suite is Apache-2.0 across all components (v1)

- **Status:** accepted
- **Date:** 2026-07-08
- **Deciders:** project owner

## Context and problem statement

The suite needs a license. An earlier sketch floated a split — a permissive core plus a source-available
(BSL) "operator plane" — to reserve commercial-hosting rights. What does v1 ship under?

## Decision

**Every component ships under Apache-2.0 for v1** — `seedward-libs`, `seedward-gentool`,
`seedward-chaincoord`, `seedward-rehearsal`, `seedward-chaincoord-web`, and `seedward-cli`. One permissive
license across the whole suite, with no per-component or per-plane variation.

## Consequences

- **Good:** unambiguous, standard, and permissive — trivial to adopt, embed, and contribute to, with no
  source-available friction for operators or integrators.
- **Good:** Apache-2.0's explicit **patent grant** covers the cryptographic / validation surface.
- **Not a forever-commitment:** a future dual-license or source-available split (e.g. BSL on an operator /
  commercial plane) remains possible for later versions, and would be its own ADR superseding this one for
  the affected components.

## Alternatives considered

- **Apache-2.0 core + BSL operator plane** — deferred: a source-available split adds licensing complexity
  and adoption friction that v1 doesn't need; revisit if/when a commercial-hosting concern is real.
- **MIT** — rejected: Apache-2.0's explicit patent grant is preferable for cryptographic code.

## Related

- The components it covers: [Architecture overview](../architecture/overview.md) + [ADR-0022](0022-suite-topology-naming-composition.md).
  Supersede per-component if a future plane split is adopted.
