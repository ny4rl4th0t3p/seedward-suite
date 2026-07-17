# Seedward Suite

Self-hostable operator tooling for the **Cosmos SDK chain-launch lifecycle** — from M-of-N committee
coordination through gentx collection, pre-flight rehearsal, and genesis finalization.

This site is the **cross-cutting** home: how the pieces fit, the contracts between them, and the
architectural decisions behind them. Each component keeps its own reference docs in its own repo.

## Start here

- [**Architecture overview**](architecture/overview.md) — the components, what must run, and the bridge.
- [**Decisions**](decisions/index.md) — the ADRs: *why* it's shaped this way.

## One-line mental model

`coordd` (seedward-chaincoord) is the **only mandatory process**. The web UI and the rehearsal daemon
are optional bolt-ons; everything else is a library or a build-time tool.

## Component status

Maturity per component — the durable signal (exact tags move each release; see each repo's releases):

| Component                             | Status                                                                                 |
|---------------------------------------|----------------------------------------------------------------------------------------|
| **seedward-chaincoord** (`coordd`)    | Release candidate — v1 imminent                                                        |
| **seedward-libs**                     | Stable — shared primitives (canonicaljson, gentxvalidate)                              |
| **seedward-gentool**                  | Pre-1.0 — genesis + rehearsal engine, API still settling                               |
| **seedward-rehearsal** (`rehearsald`) | 🚧 **Heavy development** — optional bolt-on; expect breaking changes before v1         |
| **seedward-chaincoord-web**           | 🚧 **Heavy development** — proof of concept, not for production; big changes before v1 |
| **seedward-cli**                      | Not shipping for v1 — commands are stubs                                               |

!!! warning "Moving fast"
**seedward-rehearsal** and **seedward-chaincoord-web** are under **heavy development** — expect
substantial, breaking changes before their v1. Pin exact tags and don't build on their current surface.