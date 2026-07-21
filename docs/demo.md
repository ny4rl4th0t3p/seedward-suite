# Demo fixture

The suite ships a runnable demo: `make dev-seed` populates a local coordd with **10 launches spanning every reachable
lifecycle state**, built by driving coordd's real REST API exactly as coordinators, committee members, and validators
would — no database fixtures, no shortcuts. Import the demo mnemonic into a wallet and you can browse and act on all of
it in the web UI.

!!! danger "Public throwaway mnemonic — insecure by design"
Every demo account derives from the public BIP39 test vector below. The keys are world-known. **Never reuse them, never
send real funds to these addresses, never expose the demo stack to the internet.**

## Run it

```sh
cp docker/.env.example docker/.env
make dev-accounts   # prints the account table; copy account 0's address into
                    # COORD_ADMIN_ADDRESSES in docker/.env
make dev-up         # coordd + web UI (http://localhost:3000)
make dev-seed       # builds the 10-launch fixture
```

`make dev-reseed` resets the volumes and re-runs the whole cycle — the iteration loop. Details on how the seeder works
live in
[`docker/seeder/README.md`](https://github.com/ny4rl4th0t3p/seedward-suite/blob/main/docker/seeder/README.md).

## Accounts & roles

16 accounts derive from `DEMO_MNEMONIC` on the Cosmos HD path `m/44'/118'/i'/0/0` — the BIP-44 **account** index is `i`.
To act as account `i` in Keplr/Leap, import the recovery phrase and set the derivation path's **account** field to `i`
(leave change/index at 0); account 0 is the wallet's default import.

| idx  | role                | can create launches? | notes                                                                        |
|------|---------------------|----------------------|------------------------------------------------------------------------------|
| 0    | admin + coordinator | yes                  | the `COORD_ADMIN_ADDRESSES` account; sees every launch (view-only allowlist) |
| 1    | coordinator         | yes                  | on the coordinator allowlist                                                 |
| 2    | committee delegate  | **no**               | governs launches (committee lead) but is not on the coordinator allowlist    |
| 3–14 | validators          | —                    | join / get approved across launches                                          |
| 15   | unauthorized        | no                   | member of nothing — demonstrates the privacy model                           |

The demo mnemonic (the standard BIP39 test vector):

```
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

Addresses and raw private keys are **generated, never hand-authored** — print the full credentials table (idx, role,
address, privkey hex) with:

```sh
make dev-accounts
```

Account 2 is the pivot of the role model: chaincoord splits **coordinator** (may *create* launches — gated by the
allowlist under `launch_policy=restricted`) from **committee member** (governs a launch it sits on). idx 2 leads three
committees yet gets a 403 on `POST /api/v1/launch`
([ADR-0026](decisions/0026-coordinator-vs-committee-member.md)).

## The launches

One launch per reachable lifecycle state, plus type, governance, and delegation variety:

| #  | Launch (chain id)       | Type                 | State           | Governance                                                       | Validators                                                                             |
|----|-------------------------|----------------------|-----------------|------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| 1  | Aurora (`aurora-1`)     | TESTNET              | `DRAFT`         | 1-of-1 (idx 1)                                                   | —                                                                                      |
| 2  | Borealis (`borealis-1`) | INCENTIVIZED_TESTNET | `PUBLISHED`     | 1-of-1 (idx 1)                                                   | —                                                                                      |
| 3  | Cascade (`cascade-1`)   | MAINNET              | `WINDOW_OPEN`   | **2-of-3** — lead idx 2, members idx 1 + idx 0; created by idx 1 | 3, 4 approved; **val 5 approval left `PENDING_SIGNATURES`**; 6–8 allowlisted, unjoined |
| 4  | Delta (`delta-1`)       | TESTNET              | `WINDOW_CLOSED` | 1-of-1 (idx 1)                                                   | 3, 4, 9, 10 approved                                                                   |
| 5  | Echo (`echo-1`)         | MAINNET              | `GENESIS_READY` | 1-of-1 (idx 0)                                                   | 3, 4, 5, 11, 12 approved                                                               |
| 6  | Gale (`gale-1`)         | PERMISSIONED         | `CANCELED`      | 1-of-1 (idx 2); created by idx 1                                 | —                                                                                      |
| 7  | Halo (`halo-1`)         | TESTNET              | `DRAFT`         | 1-of-1 (idx 1)                                                   | —                                                                                      |
| 8  | Ion (`ion-1`)           | MAINNET              | `PUBLISHED`     | 1-of-1 (idx 2); created by idx 1                                 | —                                                                                      |
| 9  | Juno (`juno-demo-1`)    | INCENTIVIZED_TESTNET | `WINDOW_CLOSED` | 1-of-1 (idx 0)                                                   | 6, 7, 8, 13 approved                                                                   |
| 10 | Kilo (`kilo-1`)         | TESTNET              | `WINDOW_OPEN`   | 1-of-1 (idx 1)                                                   | 9, 10 approved; 11–14 allowlisted, unjoined                                            |

What each is there to show:

- **Cascade — the centerpiece.** A 2-of-3 committee **led by the non-coordinator idx 2** (full delegation: idx 1 created
  the launch, then has no committee seat on it). Every executed proposal carries two signatures, and val 5's
  `APPROVE_VALIDATOR` sits live at `PENDING_SIGNATURES` — open it as idx 1 or idx 0 to co-sign, veto, or leave it
  pending. Validators 6–8 are allowlisted but unjoined: the window is open, so you can join it yourself (below).
- **Echo — the gentool genesis.** Its final genesis was assembled with
  [gentool](https://github.com/ny4rl4th0t3p/seedward-gentool) rather than `collect-gentxs`:
  treasury/ops accounts, delayed-vesting claims (one pre-delegated to a validator), a continuous-vesting grant,
  `authz` + `feegrant` seeds, and a community pool. Open Echo and use the **Genesis Files** card →
  **Download genesis-final.json** to inspect `app_state` (empty `gen_txs`, validators baked into
  `staking.validators`, the vesting accounts, and the community pool).
- **Gale / Ion — delegated creation.** Created by coordinator idx 1 but governed solely by idx 2 — the creator retains
  no power (Gale was then canceled by its lead from `PUBLISHED`).
- **Delta / Juno** — closed windows awaiting genesis; **Aurora / Halo / Borealis / Kilo** — early states plus list
  variety.

**Visibility is the demo, too.** Launches are private-always — visible only to committee ∪ allowlist
([ADR-0012](decisions/0012-private-always-membership-visibility.md)). Account 0 sees all 10 (it is a *view-only*
allowlist member of every launch it doesn't govern), idx 2 sees exactly the 3 it governs, and idx 15 sees none — a
private launch is a 404 for it even when authenticated.

## Join Cascade yourself

Cascade's window is open and validators 6–8 are allowlisted but unjoined. As account 6:

1. Import the demo mnemonic into Keplr/Leap with the derivation path's **account** field set to `6`, and connect to the
   web UI (http://localhost:3000).
2. Open **Cascade** and, in the **Genesis Files** card, click **Download genesis-initial.json** — the pre-gentx base
   genesis (the card verifies its SHA-256 for you). You'll build your gentx against it.
3. Build a gentx against it with gaiad (self-delegation `100000000umars`, the record allows commission rate ≤ 0.50,
   change rate ≤ 0.10, min self-delegation 1):

   ```sh
   gaiad init val6 --chain-id cascade-1 --home ~/.cascade-val6
   # overwrite the fresh init genesis with the downloaded genesis-initial.json, then:
   cp ~/path-to-initial-genesis/genesis-initial.json ~/.cascade-val6/config/genesis.json
   gaiad keys add val6 --recover --account 6 --keyring-backend test --home ~/.cascade-val6
   gaiad genesis add-genesis-account val6 100000000umars --keyring-backend test --home ~/.cascade-val6
   gaiad genesis gentx val6 100000000umars --chain-id cascade-1 \
     --moniker val6 --commission-rate 0.05 --commission-max-rate 0.20 \
     --commission-max-change-rate 0.01 --min-self-delegation 1 \
     --keyring-backend test --home ~/.cascade-val6
   gaiad comet show-node-id --home ~/.cascade-val6   # → <node_id> for the peer address
   ```

4. Submit the join request from the launch page. The form needs the generated gentx JSON (from
   `~/.cascade-val6/config/gentx/`), a **peer address** in the form `<node_id>@<host>:<port>` (use the
   node id printed above with any placeholder host, e.g. `<node_id>@203.0.113.1:26656` — nothing dials
   it in the demo), and an **RPC endpoint** (any well-formed URL, e.g. `http://203.0.113.1:26657`).
   The gentx is validated client-side (WASM) and server-side before acceptance.
5. Switch wallets to idx 2 (the lead) to raise the `APPROVE_VALIDATOR` proposal, and to idx 1 or idx 0 to provide the
   second signature.

## Demo-only coordd configuration

The dev compose stack sets flags on coordd that exist **for the demo, never for production**:

- `COORD_LAUNCH_POLICY=restricted` — creation gated to the seeded coordinator allowlist (idx 0, 1).
- `COORD_GENESIS_HOST_MODE=true` — coordd accepts raw genesis uploads (the seeder posts bytes, not URLs).
- `COORD_INSECURE_NO_RATE_LIMIT=true` — the seeder authenticates 15 accounts rapidly from one IP.

## Not included

`LAUNCHED` needs a live chain reaching block 1 under coordd's block monitor — deferred to a future
`make dev-seed-launched` real-chain profile. The rehearsal bolt-on is off in the demo stack.
