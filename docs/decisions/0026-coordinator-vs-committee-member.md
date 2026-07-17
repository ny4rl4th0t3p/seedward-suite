# ADR-0026 · "Coordinator" is the launch creator; the in-launch governance seat is a "committee member"

- **Status:** accepted
- **Date:** 2026-07-16
- **Deciders:** project owner

## Context and problem statement

The word "coordinator" was overloaded across two distinct principals — in the API field names, the Go
identifiers, and the docs — so a "coordinator" reference could mean either of:

1. The **creator** of a launch: an address on the admin **coordinator allowlist**, the only role permitted
   to create launches (`POST /launch`, gated by `is_coordinator` / the coordinator allowlist under
   `launch_policy=restricted`). This principal need not participate in the launch it creates.
2. An **in-launch M-of-N governance seat**: a member of a launch's committee (`committee.members`) that
   raises, signs, and vetoes proposals.

One word naming two different roles is misleading — most sharply, the proposal-signature field was named
`coordinator_address` when it actually carries a *committee member's* address. What is the canonical
vocabulary?

## Decision

Two distinct terms, used consistently across coordd, the OpenAPI spec, the web, and the docs:

- **Coordinator** — an address on the admin **coordinator allowlist**; the role that may **create**
  launches. A server-plane / creation concern (`is_coordinator`, `coordinator_allowlist`,
  `CoordinatorAdded/Removed`, the `POST /launch` gate). A coordinator **need not** sit on any committee.
- **Committee member** — an in-launch **M-of-N governance seat** (`committee.members`) that raises, signs,
  and vetoes proposals. The proposal-signature field is a committee member's address.
- **Lead** — `Members[0]`, the committee's first member. A **thin lead**: it holds only the early-stage
  direct cancel and DRAFT reconfigure ([ADR-0025](0025-cancel-governance-hybrid.md)), not a separate
  authority tier.

"Coordinator" is retained **only** for the creation/allowlist sense; every in-launch governance reference
is "committee member" (or "lead").

## Consequences

- **Good:** the two principals are unambiguous — an API consumer or reader can tell a launch *creator*
  (allowlist) from an in-launch *governance seat*.
- **Breaking wire change:** the proposal raise/sign field `coordinator_address` was renamed
  `member_address`. Because it sits **inside the ADR-036 signed bytes**, coordd, the OpenAPI spec, and the
  generated web client had to move in lockstep ([ADR-0020](0020-openapi-source-of-truth.md)) — a rename on
  one side would otherwise break signature reconstruction or fail CI's drift gate.
- **Docs + code re-cast:** `roles.md` and `concepts/*` name the in-launch role "committee member" /
  "committee lead"; Go identifiers and comments that said "coordinator" but meant a committee member were
  swept. "Coordinator" stays for the allowlist/creator.
- **Trade-off:** a one-time breaking rename across coordd + spec + web — taken pre-v1 while the surface is
  still moving, rather than carrying the ambiguity into a stable release.

## Alternatives considered

- **Keep "coordinator" for both roles** — rejected: the overload *is* the problem; it conflates a
  creation/allowlist role with an in-launch governance seat.
- **Rename the creation role instead (e.g. "creator")** — rejected: "coordinator allowlist" / `is_coordinator`
  is the established server-plane vocabulary and fits a launch *coordinator* who sets one up; the in-launch
  seat is the term that was actually misapplied.

## Related

- The M-of-N governance the seat participates in: [ADR-0010](0010-m-of-n-committee-proposal-governance.md).
  The lead's stage-dependent cancel: [ADR-0025](0025-cancel-governance-hybrid.md). Membership/visibility:
  [ADR-0012](0012-private-always-membership-visibility.md). The spec/client lockstep the rename relied on:
  [ADR-0020](0020-openapi-source-of-truth.md). Reference: chaincoord [concepts/roles.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/roles/).
