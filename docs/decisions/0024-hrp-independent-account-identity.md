# ADR-0024 · The hot identity is the HRP-independent account

- **Status:** accepted
- **Date:** 2026-07-08
- **Deciders:** project owner

## Context and problem statement

A Cosmos account **is** the 20 bytes `ripemd160(sha256(pubkey))`; the bech32 HRP (`cosmos`, `osmo`, a
launch's own prefix) is only a per-chain *display* prefix over those same bytes. coordd's original hot
identity (auth / submitter / membership) was the bech32 **string**, so `cosmos1<h>` and `network1<h>` — the
same account — were treated as different identities. That locked an operator to whichever HRP they first
authenticated with, and it reinforced the need for a public `chain-hint` (the ADR-0012 leak): the bootstrap
assumed a member had to present a launch-prefix address, which needed the prefix, which needed `chain-hint`.

## Decision

**The hot identity is the HRP-independent account (the 20 bytes), not the bech32 string** — refining
[ADR-0011](0011-adr036-challenge-response-auth.md) (address-is-identity) and the hot side of
[ADR-0013](0013-submitter-validator-identity-split.md).

- **One value type.** `launch.AccountID` *is* the account: it decodes any account-form bech32 to the 20
  bytes, `Equal` / map-keying compare the account (so `cosmos1<h>` ≡ `network1<h>`), and it renders under
  any HRP via `Bech32(hrp)`. It **rejects** validator-entity forms (`…valoper…`, `…valcons…`) — those are
  network-bound and never an account.
- **Auth accepts any account HRP.** The ADR-036 signature is unchanged (it still binds the claimed address
  string); after verification the account is derived and used as the identity. The challenge, nonce, and
  session-revocation fence are keyed on the **account**, so a nonce consumed under one prefix cannot be
  replayed under another.
- **Every authorization compares on the account** — membership, committee, admin, coordinator, visibility.
  A member / coordinator / admin added under one prefix is recognized under any.
- **Storage is canonicalized.** Launch-scoped addresses (members, committee, join-request submitter +
  operator) are stored under the **launch's own bech32 prefix** — the DB reads chain-native (`network1…`)
  and the per-submitter cap counts by account. Global identities with no launch to anchor a prefix (the
  coordinator allowlist, the session-revocation fence) are stored as the **account hex**. A startup
  backfill canonicalizes existing rows.
- **`chain-hint` is gated.** With the account as identity, `GET /launch/{id}/chain-hint` moved behind the
  visibility check (404 for non-members), closing the ADR-0012 existence leak. An operator authenticates
  with any existing address, then reads `chain-hint` to learn the launch prefix for their gentx.

## Consequences

- **Good:** an operator uses any wallet / HRP as one identity; a launch's own prefix is purely a rendering;
  the `chain-hint` leak is closed.
- **Good:** the DB reads consistently — launch-scoped rows under the launch prefix, global identities as
  account hex — with no mixed prefixes for one account.
- The **cold validator operator address is unchanged**: it stays launch-prefix ([ADR-0013](0013-submitter-validator-identity-split.md)),
  network-bound by design — this decision touches only the hot side.

## Alternatives considered

- **Keep the bech32 string as the identity** — rejected: locks an operator to one HRP and forces the public
  `chain-hint` bootstrap.
- **Account hex everywhere (incl. launch-scoped)** — rejected for launch-scoped data: less readable than the
  chain-native launch-prefix form; hex is reserved for global identities with no prefix to anchor.

## Related

- Refines [ADR-0011](0011-adr036-challenge-response-auth.md) and
  [ADR-0013](0013-submitter-validator-identity-split.md); closes the `chain-hint` leak in
  [ADR-0012](0012-private-always-membership-visibility.md). Reference: chaincoord [concepts/roles.md](https://ny4rl4th0t3p.github.io/seedward-chaincoord/concepts/roles/) +
  [decisions/](https://ny4rl4th0t3p.github.io/seedward-chaincoord/decisions/).
