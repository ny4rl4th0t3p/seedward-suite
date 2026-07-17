# ADR-0012 · Launches are private-always; visibility is committee ∪ members

- **Status:** accepted
- **Date:** 2026-07-05
- **Deciders:** project owner

## Context and problem statement

Who may see, read, and submit to a launch? An early design had a `PUBLIC`/`ALLOWLIST` visibility axis.
Should launches ever be publicly discoverable?

## Decision

**Every launch is private-always** — the `PUBLIC`/`Visibility` enum and field were deleted:

- **Visible ⇔ submit-allowed ⇔ caller ∈ committee ∪ members-list.**
  `Launch.IsVisibleToAddr = Committee.HasMember(addr) || Allowlist.Contains(addr)`.
- **Non-members get 404, not 403**, on both `GET /launch/{id}` and `POST /launch/{id}/join` —
  existence-hiding, so a URL alone reveals nothing.
- The **members list is hot addresses + labels**, managed directly by the committee (`POST/DELETE/GET
  /launch/{id}/members`, no proposal) while the launch is DRAFT/PUBLISHED/WINDOW_OPEN.
- **Validators are not allowlisted.** Membership governs who can *see/submit*; a validator is *admitted*
  by committee approval anchored on its derived operator address ([ADR-0013](0013-submitter-validator-identity-split.md)),
  reviewed grouped by submitter.

## Consequences

- **Good:** no launch is publicly enumerable; a leaked URL discloses nothing to a non-member.
- **Good:** membership (see/submit) and admission (approval) are cleanly separated.
- **Trade-off:** onboarding must add a validator's hot address as a member before it can participate.

## Resolved — the `chain-hint` existence leak (closed by ADR-0024)

> **Resolved by [ADR-0024](0024-hrp-independent-account-identity.md).** With the hot identity now the
> HRP-independent account, `chain-hint` is gated behind the visibility check (`optionalAuth` → 404 for
> non-members) like every other read. The original open-issue note is kept below for the record.

`GET /launch/{id}/chain-hint` is currently **unauthenticated and bypasses visibility** — it returns
`chain_id`, `chain_name`, `bech32_prefix`, `denom` to anyone with the URL (enforced by
`TestHandleChainHint_NoAuthRequired` / `_AllowlistLaunchVisible`). Its rationale is bootstrap: a
prospective validator needs the bech32 prefix to derive the address it must hand the committee before it
can be a member. **But this contradicts the 404 existence-hiding above** — the URL will leak eventually,
and this endpoint confirms the launch exists and leaks its chain identity/params. This is a **known open
security issue, not a blessed design.** Intended resolution: gate `chain-hint` behind membership and
convey the chain params during onboarding (out-of-band, or via the future invite token). **Tracked for
the security pass (C4).**

## Alternatives considered

- **`PUBLIC`/`ALLOWLIST` visibility** — removed: a public launch is an enumeration/attack surface with no
  operator benefit here.
- **403 for non-members** — rejected: confirms the launch exists; 404 existence-hiding is stronger.

## Related

- Reference: chaincoord [concepts/roles.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/roles/) (Membership), [concepts/overview.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/overview/). Identity split:
  [ADR-0013](0013-submitter-validator-identity-split.md). Auth: [ADR-0011](0011-adr036-challenge-response-auth.md).
  Invite-token onboarding (v1.x) + members-API mechanics: chaincoord [decisions/](https://ny4rl4th0t3p.github.io/seedward-chaincoord/decisions/).
