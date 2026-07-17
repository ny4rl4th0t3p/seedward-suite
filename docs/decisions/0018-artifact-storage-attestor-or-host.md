# ADR-0018 · Large artifacts (genesis, allocations) are attestor-referenced or host bytes — coordd never holds them

- **Status:** accepted
- **Date:** 2026-06-10
- **Deciders:** project owner

## Context and problem statement

A launch's genesis and allocation files can be large (airdrop-scale accounts → hundreds of MB). coordd is
a lightweight coordination server. How does it handle these artifacts without becoming a large-object
store or buffering them in memory?

## Decision

Every large artifact (initial/final genesis, each allocation file) is uploaded in one of two modes, and
coordd stores a **reference or streams to disk — never buffers in memory:**

- **Attestor mode (default, `application/json`):** the body is `{url, sha256}` — coordd stores only the
  URL + hash (SSRF-validated), persists no bytes, and serves reads via a **302 redirect** to the external
  URL. The uploader's attestor hosts the bytes.
- **Host mode (`application/octet-stream`, gated by a config flag):** raw bytes stream to disk under a
  size cap (`413` on exceed); reads stream the file.

A `StoredFileRef` carries exactly one of `ExternalURL` / `LocalPath`. coordd **stores + SHA-256-hashes but
never parses** content (it's gentool's CSV, or a genesis JSON).

## Consequences

- **Good:** coordd's memory stays constant regardless of artifact size; attestor mode means coordd needn't
  host large files at all.
- **Good:** the hash is the integrity anchor everywhere (`input_set_hash`, approval payloads, readiness
  confirmation).
- **Good:** the same by-reference model is what the rehearsal bridge streams (D8) — one artifact model
  across the suite.
- **Trade-off:** attestor-mode reads depend on the external host's availability; the hash still pins
  integrity.

## Alternatives considered

- **Inline bytes in JSON (base64)** — rejected: buffers the whole file (raw + 33 % base64 + marshal) in
  coordd memory — hundreds of MB to GB for airdrop files.
- **coordd as the file store always** — rejected: makes a coordination server a large-object store;
  attestor mode offloads it.

## Related

- The allocation files that use it: [ADR-0014](0014-allocation-files-whole-file-governance.md). The genesis
  it anchors: [ADR-0004](0004-gentool-library-first-genesis-engine.md) (built by gentool) +
  [ADR-0015](0015-input-set-hash.md). The bridge streaming that mirrors it (D8):
  [ADR-0008](0008-rehearsal-write-back-and-lease.md).
