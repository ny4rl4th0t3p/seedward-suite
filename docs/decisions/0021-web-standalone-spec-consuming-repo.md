# ADR-0021 · The web control panel is a standalone repo generated from coordd's spec

- **Status:** accepted
- **Date:** 2026-07-06
- **Deciders:** project owner

## Context and problem statement

coordd needs a browser control panel. Early on it lived *inside* coordd (a `web/app` embedded via
`go:embed`). Should the frontend stay coupled to the server, or be its own thing?

## Decision

**The web panel is its own repo, `seedward-chaincoord-web`, and consumes coordd's API only through the
generated client — it is never embedded in coordd:**

- It talks only to coordd's HTTP API; there is no shared code, only the OpenAPI contract.
- The typed client is orval-generated react-query hooks off the **vendored** spec (`openapi/swagger.yaml`,
  copied from coordd via `sync:spec`), so the web builds without coordd present.
- The two ship and version **independently** (the web is `0.1.0`; the spec carries coordd's API version —
  [ADR-0020](0020-openapi-source-of-truth.md)).

## Consequences

- **Good:** frontend and server evolve on their own cadence — the web is a plain Next.js app (no Go
  toolchain), the server has no frontend build and no bloated binary.
- **Good:** the only coupling is the spec, and a drift gate (`gen:api` vs the vendored spec) catches any
  divergence.
- **Good:** leaves the `seedward-web` name free for a future *suite-wide* dashboard (this one is
  chaincoord-specific).
- **Trade-off:** the spec must be re-synced (`sync:spec`) + the client regenerated when coordd's API
  changes — enforced by the drift gate.

## Alternatives considered

- **Embed the web in coordd (`go:embed`)** — rejected: couples a Go server to a JS build, forces lockstep
  releases, and bloats the coordd binary.
- **A hand-written API client** — rejected: drifts from the spec (the client is generated — ADR-0020).

## Related

- The generated-client + spec-as-contract mechanism: [ADR-0020](0020-openapi-source-of-truth.md). The auth
  it performs: [ADR-0011](0011-adr036-challenge-response-auth.md). The client-side gentx validation it
  embeds: [ADR-0002](0002-client-side-gentx-validation-wasm.md). Web-internal choices:
  [seedward-chaincoord-web/docs/decisions.md](https://github.com/ny4rl4th0t3p/seedward-chaincoord-web/blob/main/docs/decisions.md).
