# ADR-0015 · `input_set_hash` — the fingerprint binding a genesis (and rehearsal) to its approved inputs

- **Status:** accepted
- **Date:** 2026-06-25
- **Deciders:** project owner

## Context and problem statement

Several features need to answer *"are these the exact inputs this genesis/rehearsal was built from, and
have they changed?"* — the genesis↔approved-set consistency guards, the rehearsal gate's staleness check,
and the bridge's result binding. They need one deterministic fingerprint of a launch's approved input set.

## Decision

**`input_set_hash` is a SHA-256 over the canonical JSON of a launch's approved inputs:** the chain
parameters, the approved gentxs (sorted; each by its `sha256` + operator + consensus key), and each
approved allocation file's SHA-256 (per type; null when absent). Computed by `computeInputSetHash`
(`services/input_set_hash.go`) over `canonicaljson`.

- It covers everything that changes the built genesis and **nothing else** — lifecycle status and
  timestamps are excluded, so a result stays *current* across status transitions while the inputs are
  unchanged.
- Allocation *content* is not hashed — only each file's already-approved SHA-256 (the file model,
  [ADR-0014](0014-allocation-files-whole-file-governance.md), is the content anchor).

## Consequences

- **Good:** one value answers "did the inputs change?" — the consistency guards bind the uploaded genesis
  to it, the rehearsal gate judges staleness by it, and the bridge anchors each result fact to the set it
  ran against.
- **Good:** deterministic (canonical JSON removes ordering/whitespace variance).
- The shape is a **cross-repo contract:** coordd computes it, the rehearsal service echoes it in result
  facts, and the gate recomputes it live.

## Alternatives considered

- **Hash the built genesis** — rejected: it can't tell you *which* input drifted, and the rehearsal
  service builds its own baseline anyway.
- **Include status/time** — rejected: would spuriously invalidate a still-valid result on every lifecycle
  transition.

## Related

- The consistency guards + gate that key off it: [ADR-0003](0003-rehearsal-optional-bolt-on.md). The
  bridge result binding: [ADR-0008](0008-rehearsal-write-back-and-lease.md) + the bridge contract. The
  allocation files it references: [ADR-0014](0014-allocation-files-whole-file-governance.md).
