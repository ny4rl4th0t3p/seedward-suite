# ADR-0017 · The audit log is a tamper-evident, hash-chained, signed append-only record

- **Status:** accepted
- **Date:** 2026-05-15
- **Deciders:** project owner

## Context and problem statement

Every governance action must be accountable and non-repudiable — a committee member can't later deny a
decision, and no one (including a compromised server) can silently rewrite history. How is that
guaranteed?

## Decision

coordd keeps a **tamper-evident, append-only JSONL audit log** where each entry is:

- **Ed25519-signed** by the server's audit key (over canonical JSON via `canonicaljson`), and
- **hash-chained** — each entry carries the SHA-256 `prev_hash` of the prior line, so the log is a linked
  chain.
- The **chain tip is persisted** (SQLite) and **re-verified at startup**: the server **refuses to boot**
  if the on-disk log's tip doesn't match the persisted one (detecting truncation or rewrite).
- `coordd audit verify` re-derives the whole chain offline — signatures, monotonic timestamps, and
  `prev_hash` continuity.

## Consequences

- **Good:** an entry can't be altered (breaks its signature) or removed (breaks the chain + tip) without
  detection; even a compromised server can't silently rewrite the past.
- **Good — the suite-wide reason this is here:** the same Ed25519 + canonical-JSON signing scheme is what
  the rehearsal service uses for its result facts ([ADR-0007](0007-bridge-fact-based-trust-boundary.md) /
  [ADR-0008](0008-rehearsal-write-back-and-lease.md)), and those facts land in this log — one accountability
  scheme across the suite.
- **Trade-off:** the audit key is a secret the deployment must protect (file-based); losing it breaks new
  signing, not verification of the past.

## Alternatives considered

- **Per-entry signatures only (no chain)** — insufficient: doesn't detect deletion/truncation of whole
  entries.
- **An external append-only ledger** — heavier; a signed hash-chain in a plain JSONL file is verifiable
  with one CLI and no extra infrastructure.

## Related

- Reference: chaincoord [reference/audit.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/reference/audit/) (the log + `audit verify`) and [concepts/security](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/security/) (the trust
  model). The rehearsal fact scheme it mirrors: ADR-0007/0008. Format + verification internals: chaincoord
  [decisions/](https://ny4rl4th0t3p.github.io/seedward-chaincoord/decisions/).
