# ADR-0020 · The OpenAPI spec is the source of truth for the coordd API

- **Status:** accepted
- **Date:** 2026-07-01
- **Deciders:** project owner

## Context and problem statement

coordd exposes an HTTP API that the web app (and, later, a CLI) consume. How is the API contract defined,
and kept in sync between the server and its clients?

## Decision

**coordd's OpenAPI spec (`swagger.yaml`) is the single source of truth, generated from the handlers:**

- Handler `swaggo` annotations → `make swagger` (`swag init`) → `docs/mkdocs/api/swagger.yaml`. The spec is
  **generated from the code**, never hand-written.
- A **drift gate** (`make swagger-check` — `git diff --exit-code` on the regenerated file) fails CI if the
  committed spec is stale, so the spec can't lag the handlers.
- The **web client is generated from the spec** (orval), and the web repo has its own drift gate
  (`gen:api`) against the vendored spec (`sync:spec`). So the web can't disagree with coordd's contract —
  a rename in a handler propagates spec → client, or CI fails.
- **Every client is generated + pinned, never hand-written.** `seedward-cli` — also owned in-suite — will
  generate its Go client from the same spec and pin + drift-gate it, exactly like the web, when its
  coordd-facing commands land. coordd has **no hand-written, external, or arbitrary-version clients.**
- **The API is root-mounted, not path-versioned** (`/launch`, not `/api/v1/launch`). Path versioning
  (`/api/v1`, `/api/v2`) exists to serve external clients *you don't control* on coexisting versions —
  which don't exist here, since every consumer is an owned, generated, version-matched client. Versioning
  is the spec's `info.version` + version-matched deploys; a breaking change bumps the spec and regenerates
  all clients (gated both sides). The `/bridge/*` prefix is *functional* (ops-plane network isolation),
  not a version.

## Consequences

- **Good:** one contract, generated both ways — no hand-maintained API docs, no hand-written client to
  drift.
- **Good:** a breaking API change shows up as a spec diff + a regenerated-client diff, gated on both sides.
- **Trade-off:** the spec's quality depends on annotation discipline (swaggo tags on every handler);
  `vacuum` lints the spec.

## Alternatives considered

- **Hand-written OpenAPI + hand-written client** — rejected: two artifacts to keep in sync with the code by
  hand; guaranteed drift.
- **No spec; prose API docs** — rejected: the web client would be hand-written and drift silently.
- **`/api/v1/` path versioning** — rejected: its only benefit (serving coexisting versions to external
  clients you don't control) doesn't apply — every client is owned + generated + version-matched, so the
  spec `info.version` + matched deploys *is* the versioning story. Root-mount stays.

## Related

- The web consuming side: `seedward-chaincoord-web` generates its orval client off the vendored spec
  (`sync:spec` + `gen:api` drift gate). Reference: chaincoord [reference/api.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/reference/api/) (embeds the spec).
