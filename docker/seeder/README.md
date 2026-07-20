# Demo seeder

Populates a running coordd with a demo fixture by driving its **real REST API** (no DB backdoor), so the whole launch
lifecycle is exercised exactly as a real coordinator/validator would. Built and run by `make dev-seed`.

## Run

Set these in `docker/.env` (copy `docker/.env.example`):

- `DEMO_MNEMONIC` — the BIP39 mnemonic all accounts derive from (defaults to the public test vector).
- `COORD_ADMIN_ADDRESSES` — account 0's address; get it from `make dev-accounts`.

```sh
make dev-accounts   # print the account table; copy account 0 into COORD_ADMIN_ADDRESSES in .env
make dev-up         # coordd (restricted policy, host-mode genesis, rate limit off) + web
make dev-seed       # derive accounts, seed coordinators, build the launch fixture
```

**Re-seed:** coordd state persists in its volume, so a fixture is built once against a fresh coordd.
`make dev-reseed` does the full cycle in one shot (reset volume → start detached → seed); it's the
iteration loop. (Equivalent to `make dev-down && make dev-up && make dev-seed`.)

## Accounts & roles

16 accounts, derived from `DEMO_MNEMONIC` on the Cosmos HD path `m/44'/118'/i'/0/0` — the BIP-44
**account** index is `i` (the `idx` column below). To act as account `i` in Keplr/Leap, add the
recovery phrase and set the derivation path's **account** field to `i` (leave change/index at 0);
account 0 is the wallet's default. `DERIVE_BY=index` re-derives on `m/44'/118'/0'/0/i` (varying the
address index instead) if you prefer.

| idx  | role                | can create launches? | notes                                                                                    |
|------|---------------------|----------------------|------------------------------------------------------------------------------------------|
| 0    | admin + coordinator | yes                  | also the `/admin` address (`COORD_ADMIN_ADDRESSES`)                                      |
| 1    | coordinator         | yes                  | on the coordinator allowlist                                                             |
| 2    | committee delegate  | **no**               | governs (signs proposals, can be committee lead) but is not on the coordinator allowlist |
| 3–14 | validators          | —                    | join / get approved across launches                                                      |
| 15   | unauthorized        | no                   | member of nothing (demoes a 404 / rejected action)                                       |

Launches are **private-always** — visible only to their committee ∪ allowlist. The seeder adds
account 0 as a **view-only** member (allowlist, not committee) of every launch it doesn't already
govern, so the front-door account sees the whole fixture while only *governing* the 3 it's on the
committee of. Account 2 (the delegate) sees only its 3; account 15 sees none — the privacy model on
display, not a bug.

> **Public throwaway mnemonic — insecure by design.** Never reuse these keys or send them real funds.

## How it works

```
mnemonic → gaiad (HD derive + gentx) → raw hex → smoke-signer (--privkey-hex, ADR-036) → coordd
```

gaiad does the standard Cosmos HD derivation (guaranteeing wallet parity) and produces the validator gentxs;
`smoke-signer` signs coordd's ADR-036 challenges and committee proposals from each account's exported raw key. The
seeder never re-implements crypto.

The image (`Dockerfile`) `go install`s `smoke-signer` + `gentool` from pinned refs and fetches
`gaiad` — portable, no sibling checkout. `CHAINCOORD_REF` must carry smoke-signer's `--privkey-hex`
(chaincoord ≥ `v1.0.0-rc5`); override it to build against an unreleased branch/commit.

## The launch ladder

`build_launch <spec>` creates a launch and walks it to a target state, reusing rungs adapted from chaincoord's
`smoke-test.sh` (signing with `--privkey-hex`, M-of-N aware). A spec is a bash associative array:

| key                              | meaning                                                                                 |
|----------------------------------|-----------------------------------------------------------------------------------------|
| `name` `chain_id` `denom` `type` | chain-record basics (`type` = TESTNET / INCENTIVIZED_TESTNET / MAINNET / PERMISSIONED)  |
| `target`                         | state to stop at: DRAFT, PUBLISHED, WINDOW_OPEN, WINDOW_CLOSED, GENESIS_READY, CANCELED |
| `creator`                        | coordinator idx that POSTs `/launch` (default: `lead`)                                  |
| `lead`                           | committee `members[0]` (does all committee actions)                                     |
| `committee`                      | space-list of member idxs (first must equal `lead`)                                     |
| `threshold`                      | M (of N = committee size)                                                               |
| `cosign`                         | extra signer idxs applied to each M-of-N proposal to reach threshold                    |
| `min_validators`                 | `record.min_validator_count`                                                            |
| `allow` `join` `approve`         | validator idxs: allowlisted / that submit a join / that get approved                    |
| `pending_last_approve`           | `1` → leave the final `APPROVE_VALIDATOR` PENDING (needs M > 1) — the centerpiece       |

Rungs: create → upload initial genesis + `PUBLISH_CHAIN_RECORD` → `open-window` → per-validator
`gaiad gentx` + `/join` → `APPROVE_VALIDATOR` → `CLOSE_APPLICATION_WINDOW` → assemble (fund +
`collect-gentxs` + validate) → `PUBLISH_GENESIS`. `CANCELED` is a direct `/cancel` from DRAFT/PUBLISHED.

**Genesis math:** equal self-delegation per validator keeps every operator below coordd's ⅓ BFT gate at window close, so
closing launches need **≥ 4 approved validators** (4 → 25 % each).

## Demo-only coordd config

The compose stack sets these on coordd for the demo (never for production):

- `COORD_LAUNCH_POLICY=restricted` — creation gated to the seeded coordinator allowlist.
- `COORD_GENESIS_HOST_MODE=true` — accept raw genesis uploads (the seeder posts bytes, not a URL).
- `COORD_INSECURE_NO_RATE_LIMIT=true` — the seeder authenticates every account many times from one IP.

## Status / scope

Phase 1: the ladder is proven with one launch (**Proof** → GENESIS_READY). Still to come — the full
~10-launch matrix, the `gentool` custom-genesis launch, and the operator walkthrough (`docs/demo.md`). LAUNCHED is
deferred (it needs a live chain — a future `make dev-seed-launched`).
