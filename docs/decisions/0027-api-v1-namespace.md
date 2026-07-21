# ADR-0027 · coordd's REST surface is namespaced under `/api/v1`

- **Status:** accepted
- **Date:** 2026-07-21
- **Deciders:** project owner

## Context and problem statement

coordd's REST surface was mounted at the **root** of its listen address — `/launch`, `/auth`,
`/committee`, `/admin`, `/audit`, `/bridge` — with no namespace prefix. The web UI deploys same-origin (Next.js proxies
API calls to coordd so no CORS or baked backend URL is needed), which surfaced a collision class: `GET /launch/<uuid>`
was simultaneously a coordd API resource and a web page route (`/launch/[id]`). Page routes win over proxy rewrites, so
the client's launch-detail fetch received the page's HTML instead of JSON and every detail view failed — only in the
proxied (container) deployment, since e2e points the client directly at coordd and never exercises the proxy.

Two structural problems behind the incident:

1. An un-namespaced API forces any co-hosted frontend to enumerate proxy prefixes and guarantee none collide with its
   own routes.
2. There is no versioning seam in the path — a breaking v2 endpoint would have no `/v1` to coexist with.

A web-side proxy prefix (`/coord-api/*`) closes the observed failure contract-free — but shipping v1 with a known
"namespace the API in v2" breaking change queued is poor v1 planning. This is the last cheap moment: after the v1 tag, a
re-path breaks every client (the same pre-v1 window logic as the `member_address`
rename, [ADR-0026](0026-coordinator-vs-committee-member.md)).

## Decision

**Mount the entire REST surface under `/api/v1`, before v1.** One rule, one exception class:

- Everything — auth, launches, committee, admin, audit pubkey, **and the rehearsal bridge**
  (`/api/v1/bridge/*`) — lives under the mount. Keeping the bridge inside preserves a single truthful OpenAPI `basePath`
  (the bridge endpoints are in the spec).
- The **ops endpoints stay root-mounted**: `/healthz` and `/metrics` address the process, not the API contract, and sit
  outside the versioned surface (and outside the OpenAPI spec).

Client conventions that follow:

- Clients configure `…/api/v1` via their base URL or a mount-owning prefix; documentation writes endpoint paths in full
  (`POST /api/v1/auth/challenge`) so nothing needs mental resolution.
- **Server-authored wire paths are absolute from the root** and include the mount (e.g. the rehearsal-input's allocation
  `url`: `/api/v1/bridge/launches/{id}/allocations/{type}`), so a consumer resolves them against the bare host URL.
- The web's same-origin proxy uses `/api/v1` **directly** as its client API base (one Next.js rewrite
  `/api/v1/:path* → backend/api/v1/:path*`). A stopgap web-owned prefix (`/coord-api`) was used while the API was still
  root-mounted; the namespace makes it redundant — `/api/v1` is itself collision-free (no page route, no Next API route
  lives under it) — so it was removed.
- The bridge network-isolation rule becomes "restrict `/api/v1/bridge/*`"
  ([bridge contract](../reference/bridge-contract.md) D6); `rehearsald`'s client owns the prefix, so its `coordd_url`
  stays the bare host URL.

## Consequences

- **Breaking wire change, taken pre-v1:** every client moved in lockstep — the web (its API base moved to `/api/v1`; the
  generated client itself is path-relative, so its only regen was for the folded-in committee re-path), the demo seeder,
  the smoke test, and `rehearsald`'s bridge client. coordd's test harnesses prefix the mount exactly like a real
  client's base URL, and a topology pin test asserts the public mount (root paths 404; ops endpoints root) so the suite
  keeps exercising real public paths.
- **Good:** the page/API collision class is closed at the *server* (any future co-hosted frontend benefits, not just
  ours); v2 has a seam (`/api/v2` can mount beside `/api/v1`); one ingress rule isolates the ops plane.
- **Path consistency folded into the same move:** the one stray top-level resource,
  `GET /committee/{launch_id}`, was re-pathed to `GET /api/v1/launch/{id}/committee` like every other launch
  sub-resource — same breaking window, so deferring it to v2 would have contradicted this ADR's own rationale.

## Alternatives considered

- **Keep the API root-level; fix it web-side only (`/coord-api` proxy prefix + ADR).** The standard BFF pattern and
  contract-preserving — it was briefly the accepted decision, then reversed: it leaves the namespace debt in the stable
  contract, where paying it later costs a major version.
- **Namespace without a version (`/api/*`).** Closes the collision class but still no v2 seam; versioning is the same
  one-time breakage, so take it in the same move.
- **Move only `/committee/{launch_id}`.** Consistency-only; addresses neither the collision nor versioning. (Its re-path
  was instead folded into this change — see Consequences.)

## Related

- Spec-canonical lockstep the re-path rode on: [ADR-0020](0020-openapi-source-of-truth.md).
- The web as a standalone spec-consuming repo: [ADR-0021](0021-web-standalone-spec-consuming-repo.md).
- The pre-v1 breaking-change precedent applied here: [ADR-0026](0026-coordinator-vs-committee-member.md).
- Bridge prefix + isolation rule: [bridge contract](../reference/bridge-contract.md) (D6).
