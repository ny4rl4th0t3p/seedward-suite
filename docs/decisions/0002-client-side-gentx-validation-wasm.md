# ADR-0002 · gentxvalidate ships to the browser as WASM for client-side advisory validation

- **Status:** accepted
- **Date:** 2026-06-10
- **Deciders:** project owner

## Context and problem statement

The same gentx-validation logic is needed on the server (authoritative) and, ideally, in the browser
(instant feedback before a validator submits). Re-implementing it in TypeScript would fork the rules and
drift from the Go source of truth. Can the Go validator run in the browser, and at what cost?

## Decision

**Ship the Go `gentxvalidate` package as a WebAssembly blob; the browser runs the same code.**

- Sign-bytes reconstruction is **hand-rolled and cosmos-sdk-free**, so the blob is loadable (the SDK's
  codec graph would make it unshippable — see [seedward-libs/docs/decisions.md](https://github.com/ny4rl4th0t3p/seedward-libs/blob/main/docs/decisions.md)). Measured **~1.9 MB
  gzipped; budget 2 MB gz, CI-enforced**.
- JS API: two flat synchronous globals — `seedwardRunLight(gentxJSON, paramsJSON)` (advisory subset, no
  signature) and `seedwardRunAll(...)` (full, incl. signature) — each returning the `[]Result` JSON.
- `Params` and `Result` use one **snake_case JSON schema** shared by the browser, the demo, and coordd's
  API (`Result` = `{invariant, ok, reason}`), so the web reuses coordd's response rendering verbatim.
- The browser validator is **advisory**; the server (`RunAll`, incl. signature) stays authoritative.

## Consequences

- **Good:** one rule set, one language of record — the client cannot disagree with the server on logic,
  only on *version* (guarded by a pin-drift check on the web side).
- **Good:** validators see structural/param errors as they paste, before any round-trip.
- **Trade-off:** a ~2 MB (gz) blob to lazy-load; standard Go WASM's runtime floor (~723 KB gz) rules out
  a sub-MB build without TinyGo (deferred — see the repo notes).

## Alternatives considered

- **TypeScript re-implementation** — rejected: forks the rules from the Go source of truth.
- **Server-only validation** — rejected: loses the instant client feedback that motivates this.
- **cosmos-sdk in the blob** — rejected: the codec graph makes the blob unloadable.

## Related

- Web consuming side: `seedward-chaincoord-web` (lazy-load, gzip artifact, version-drift gate).
- Precondition: [ADR-0001](0001-single-gentx-validator-boundary.md) (the library is pure/embeddable).
- Repo-internal notes: [seedward-libs/docs/decisions.md](https://github.com/ny4rl4th0t3p/seedward-libs/blob/main/docs/decisions.md), [seedward-libs/docs/sign-bytes-notes.md](https://github.com/ny4rl4th0t3p/seedward-libs/blob/main/docs/sign-bytes-notes.md).