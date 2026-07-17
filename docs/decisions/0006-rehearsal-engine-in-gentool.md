# ADR-0006 · The rehearsal engine (pkg/rehearse) lives in gentool and is coordd-agnostic

- **Status:** accepted
- **Date:** 2026-06 (approx. — the engine predates any written decision)
- **Deciders:** project owner

## Context and problem statement

Pre-flight rehearsal — "does this approved gentx + allocation set actually boot and reconcile?" — needs
the genesis-build engine. Where should the rehearsal engine live, and what may it depend on? A naive
placement would put it in seedward-rehearsal and let it call coordd.

## Decision

**The rehearsal engine is `pkg/rehearse` *in gentool*, and it is coordd-agnostic.**

- It sits next to the genesis engine it uses: it builds a candidate genesis via `pkg/genesis`, boots an
  ephemeral chain, runs on-chain assertions, and tears it down.
- Its contract is `Input` / `Result` / `Outcome`, where **`Outcome` is tri-state — `PASS` / `FAIL` /
  `ERROR` — mirroring the bridge contract** coordd consumes (`ERROR` = the rehearsal couldn't run, kept
  distinct from a `FAIL`ing set), plus `errors.Is` sentinels for failure kinds.
- seedward-rehearsal is a **thin wrapper** — the standalone `rehearse` CLI and the coordd-connected daemon
  both consume this engine; nothing about coordd leaks into it.

## Consequences

- **Good:** the engine has zero coordd dependency; the entire coordd coupling (the bridge) lives in
  seedward-rehearsal, consistent with [ADR-0003](0003-rehearsal-optional-bolt-on.md).
- **PASS semantics to understand:** it boots **substitute validators** — the real gentx *consensus* keys
  aren't available to the rehearsal runner, so it swaps in keys it controls to actually produce blocks. A
  rehearsal is therefore a pre-flight **on the input set**; it emits **no publishable genesis**.

## Alternatives considered

- **Engine in seedward-rehearsal** — rejected: gentool already owns genesis construction; the engine
  belongs with it, and keeping it here lets the standalone CLI reuse it without a coordd dependency.
- **Engine calls coordd directly** — rejected: couples the engine to the server and inverts the bolt-on
  dependency direction (see ADR-0003).

## Related

- Engine reference: [seedward-gentool/docs/rehearse-engine.md](https://github.com/ny4rl4th0t3p/seedward-gentool/blob/main/docs/rehearse-engine.md). Wrapper/daemon + bridge: seedward-rehearsal
  (a later ADR). Suite wire contract: [Bridge contract](../reference/bridge-contract.md).
