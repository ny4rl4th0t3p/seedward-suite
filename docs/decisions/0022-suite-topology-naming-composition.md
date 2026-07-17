# ADR-0022 · Suite topology, naming, and composition

- **Status:** accepted
- **Date:** 2026-06-11
- **Deciders:** project owner

## Context and problem statement

The suite is several Go components (a coordination server, rehearsal, a genesis engine, shared libs, a
CLI, a web panel). How are they split into repos, named, and composed — and what keeps them usable
independently rather than fusing into a monolith?

## Decision

**One repo per component, a uniform naming convention, and standalone-first composition.**

**Topology & naming:**

- **One repo per component**, named `seedward-<component>` (`seedward-chaincoord`, `seedward-gentool`,
  `seedward-rehearsal`, `seedward-libs`, `seedward-cli`, `seedward-chaincoord-web`). The `seedward-` prefix
  carries the brand — **no GitHub org**; module paths are plain
  `github.com/ny4rl4th0t3p/seedward-<repo>` (a vanity `seedward.dev/…` path was considered and deferred).
- **Binary name ≠ repo name:** `seedward-cli`→`seedward` (`cmd/seedward/`), `seedward-chaincoord`→`coordd`
  (+ dev-only `smoke-signer`), `seedward-gentool`→`gentool`, `seedward-rehearsal`→`rehearsald` + `rehearse`.
  Deploy images carry the prefix (`seedward-chaincoord`, `seedward-rehearsal`). Bare `seedward` is the CLI
  binary; the docs/umbrella front door shipped as `seedward-suite`.

**Composition:**

- **Every component is usable standalone**; the suite is the *composition*, not a bundle. `coordd` runs
  alone; rehearsal + web are optional.
- **Library-first with thin entry points** — logic lives in importable packages, the binary is a thin
  shell ([ADR-0004](0004-gentool-library-first-genesis-engine.md)). Each Cobra tree mounts once (standalone
  at its own root, or under `seedward` as a subcommand — [ADR-0005](0005-gentool-mountable-command-tree.md)).
- **Servers never merge** into one binary; each stays its own process.
- `--version` reports the embedded library versions, so a component's compiled-in `seedward-libs` / gentool
  versions are visible (the skew rule).

## Consequences

- **Good:** each component evolves, versions, and is adopted independently; the blast radius of a change is
  one repo.
- **Good:** a consistent, predictable scheme for repos, binaries, and images.
- **Good:** no monolith — an operator can run just `coordd`, or embed `gentool`, without pulling the rest.
- **Trade-off:** cross-component changes span repos + require version bumps (mitigated by the spec/WASM
  drift gates).

## Alternatives considered

- **Monorepo** — rejected: couples release cadences and blurs the standalone boundary that lets `coordd`
  (or `gentool`) be used alone.
- **A GitHub org / vanity module path** — deferred: the `seedward-` prefix + personal handle carries the
  brand today; an org or vanity path can come later without breaking the convention.
- **One fused binary** — rejected: violates standalone-usability and forces a single release unit.

## Related

- Library-first + mountable commands: [ADR-0004](0004-gentool-library-first-genesis-engine.md),
  [ADR-0005](0005-gentool-mountable-command-tree.md). The web as a separate repo:
  [ADR-0021](0021-web-standalone-spec-consuming-repo.md). Reference: [Architecture overview](../architecture/overview.md).
