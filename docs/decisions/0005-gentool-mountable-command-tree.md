# ADR-0005 · gentool commands are mountable into a host CLI

- **Status:** accepted
- **Date:** 2026-06-11
- **Deciders:** project owner

## Context and problem statement

seedward-cli wants to offer `seedward genesis …` without re-implementing gentool's Cobra commands (which
would fork and drift). Can gentool's commands be imported and mounted under another CLI's root?

## Decision

**Expose the commands through fresh constructors with no global state.**

- `pkg/cli.NewGenesisCommands()` returns self-contained `*cobra.Command`s — no `init()`, no package
  globals, every flag (including `--config`) declared on the command itself, config held in a
  **per-command `viper.New()`** rather than the global singleton a host may use.
- A host mounts them under its own parent: `for _, c := range cli.NewGenesisCommands() { root.AddCommand(c) }`.

## Consequences

- **Good:** seedward mounts gentool's genesis commands in-process; one implementation, no duplication.
- **Two hard constraints on the embedding host:**
  1. The host **must not declare a `--config` flag** — Cobra resolves the collision silently in favour of
     gentool's command, leaving the host's flag unreachable.
  2. The suite must stay on **one `spf13/cobra` major version** so `*cobra.Command` is type-identical
     across module boundaries (a mismatch makes the mount fail to compile).

## Alternatives considered

- **Re-implement the commands in seedward** — rejected: duplication and inevitable drift.
- **Shell out to the gentool binary** — rejected: loses in-process embedding + type safety, and reintroduces
  the disk round-trip [ADR-0004](0004-gentool-library-first-genesis-engine.md) removed.

## Related

- README "Embedding as a library" (mount example + `--config` caveat); [seedward-gentool/docs/decisions.md](https://github.com/ny4rl4th0t3p/seedward-gentool/blob/main/docs/decisions.md).
