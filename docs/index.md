# Seedward Suite

Self-hostable operator tooling for the **Cosmos SDK chain-launch lifecycle** — from M-of-N committee coordination
through gentx collection, pre-flight rehearsal, and genesis finalization.

This site is the **cross-cutting** home: how the pieces fit, the contracts between them, and the architectural decisions
behind them. Each component keeps its own reference docs in its own repo.

## Start here

- [**Architecture overview**](architecture/overview.md) — the components, what must run, and the bridge.
- [**Demo fixture**](demo.md) — `make dev-seed`: a populated stack with 10 launches across every lifecycle state,
  browsable with an imported demo wallet.
- [**Decisions**](decisions/index.md) — the ADRs: *why* it's shaped this way.

## One-line mental model

`coordd` (seedward-chaincoord) is the **only mandatory process**. The web UI and the rehearsal daemon are optional
bolt-ons; everything else is a library or a build-time tool.

## Component status

Maturity per component — the durable signal (exact tags move each release; see each repo's releases):

| Component                             | Status                                                                           |
|---------------------------------------|----------------------------------------------------------------------------------|
| **seedward-chaincoord** (`coordd`)    | Stable — v1.0.0                                                                  |
| **seedward-libs**                     | Stable (v1.x) — shared primitives (canonicaljson, gentxvalidate)                 |
| **seedward-gentool**                  | Stable (v1.x) — genesis + rehearsal engine                                       |
| **seedward-rehearsal** (`rehearsald`) | Pre-release (v0.3.x) — built; not yet shipped as a stable version                |
| **seedward-chaincoord-web**           | Beta (v0.3.x) — functional; drives the full lifecycle, minimal UI still evolving |
| **seedward-cli**                      | Experimental — not shipping for v1; coordd/rehearsal commands are stubs          |

!!! warning "Pre-1.0 components move fast"
**seedward-rehearsal** (pre-release) and **seedward-chaincoord-web** (beta) may still take breaking changes before their
v1. Pin exact tags and don't build on their current surface.