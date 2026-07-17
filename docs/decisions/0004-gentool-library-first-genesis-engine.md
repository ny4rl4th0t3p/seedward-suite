# ADR-0004 · gentool is a library-first genesis engine

- **Status:** accepted
- **Date:** 2026-06-08
- **Deciders:** project owner

## Context and problem statement

gentool began as a CLI that reads inputs from disk and writes a genesis file. But chaincoord and the
rehearsal engine need to build genesis **programmatically, in-process** — a CLI-only tool forces them to
shell out and round-trip through the filesystem. Should the genesis logic be an importable library?

## Decision

**Extract the genesis logic into an importable, side-effect-limited engine; the CLI is a thin wrapper.**

- `genesis.Build(ctx, baseGenesisBytes, cfg, repos)` is the library entry point — **viper-free** and does
  **zero disk I/O** (callers own reading the baseline and saving the result). `cmd/gentool` is a thin
  shell that wires flags/files to it.
- Inputs come through a `Repositories` bundle of interfaces; CSV- and gentx-backed implementations live in
  `pkg/genesis/csv` and `pkg/genesis/gentx`, or an embedder supplies its own.
- **OOM/RAM estimation was dropped by design:** bounding memory is the caller's infrastructure job
  (`GOMEMLIMIT` + a container/cgroup limit), not the library's.

## Consequences

- **Good:** chaincoord and rehearsal embed the engine directly — no subprocess, no disk round-trip.
- **Caveat embedders MUST know — it is *side-effect-limited*, not pure:** `Build` seals the
  **process-global `sdk.Config`** (bech32 prefixes) via `sync.Once` and sets `sdk.DefaultBondDenom`. Call
  it once per process with a consistent prefix; a second call with a different prefix is silently ignored.
- **Trade-off:** the engine's public surface (domain types as import paths, the `Repositories` shape) is
  now an API contract with real consumers.

## Alternatives considered

- **CLI-only, shell out** — rejected: forces exec + filesystem round-trips on every embedder.
- **Fully pure / no globals** — not achievable: `sdk.Config` is inherently process-global in the SDK; the
  seal is the least-surprising way to make it deterministic.

## Related

- README "Embedding as a library" + "Memory & resource limits"; repo-internal notes in
  [seedward-gentool/docs/decisions.md](https://github.com/ny4rl4th0t3p/seedward-gentool/blob/main/docs/decisions.md). See also [ADR-0005](0005-gentool-mountable-command-tree.md),
  [ADR-0006](0006-rehearsal-engine-in-gentool.md).
