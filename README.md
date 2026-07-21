# Seedward Suite

Self-hostable operator tooling for the **Cosmos SDK chain-launch lifecycle**: run a multi-party
launch under an M-of-N committee, validate validator gentxs, rehearse the genesis before going
live, and keep a tamper-evident record of every decision — without the usual
Discord-and-spreadsheet scramble.

**Documentation: <https://ny4rl4th0t3p.github.io/seedward-suite>** — architecture, the demo
walkthrough, and the decision records (ADRs).

## Components

`coordd` is the only mandatory process; everything else is optional or compiled in.

| Repo                                                                                     | What it is                                                        |
|------------------------------------------------------------------------------------------|-------------------------------------------------------------------|
| [seedward-chaincoord](https://github.com/ny4rl4th0t3p/seedward-chaincoord)               | the coordination server (`coordd`) — lifecycle, governance, audit |
| [seedward-chaincoord-web](https://github.com/ny4rl4th0t3p/seedward-chaincoord-web)       | browser UI — wallet sign-in, launches, proposals, gentx submit    |
| [seedward-rehearsal](https://github.com/ny4rl4th0t3p/seedward-rehearsal)                 | optional pre-flight rehearsal daemon (`rehearsald`)               |
| [seedward-gentool](https://github.com/ny4rl4th0t3p/seedward-gentool)                     | genesis assembly CLI + engine                                     |
| [seedward-libs](https://github.com/ny4rl4th0t3p/seedward-libs)                           | shared libraries (canonicaljson, gentxvalidate + WASM build)      |
| [seedward-cli](https://github.com/ny4rl4th0t3p/seedward-cli)                             | unified CLI (experimental)                                        |

Per-component maturity lives on the
[docs home](https://ny4rl4th0t3p.github.io/seedward-suite/#component-status).

## Run the suite locally

Bring up the coordination stack (coordd + the web UI) from published images:

```bash
cp docker/.env.example docker/.env   # set COORD_ADMIN_ADDRESSES to your admin wallet address
make dev-up                          # coordd on :8080, web UI on :3000
```

Open **http://localhost:3000** and sign in with a Keplr/Leap wallet. `make dev-down` tears it down;
`make dev-pull` refreshes the pinned images (versions in `.env`).

### Try the demo fixture

Seed the stack with **10 launches spanning every reachable lifecycle state** — built through
coordd's real REST API — and browse them with an imported demo wallet:

```bash
make dev-accounts   # prints the demo account table; copy account 0 into COORD_ADMIN_ADDRESSES
make dev-up
make dev-seed       # builds the fixture (make dev-reseed = reset + re-run)
```

Full walkthrough — who's who, what each launch demonstrates, and how to join a launch yourself:
[the demo page](https://ny4rl4th0t3p.github.io/seedward-suite/demo/).

### Add pre-flight rehearsal (run rehearsald natively)

Rehearsal is the optional bolt-on (ADR-0003). Its v1 runtime boots a real chain as local processes, so it
runs best **natively** rather than in a container — run it from
[seedward-rehearsal](https://github.com/ny4rl4th0t3p/seedward-rehearsal) against the dockerized coordd:

1. Create a shared ops token — it is a plain shared secret you generate yourself (any high-entropy
   string, e.g. `openssl rand -hex 32`), not a key either side derives. Set it in `.env`
   (`REHEARSAL_OPS_TOKEN=…`) and `make dev-up` — coordd now exposes the `/api/v1/bridge/*` endpoints. Both
   sides must present the same value; semantics in the
   [coordd setup reference](https://ny4rl4th0t3p.github.io/seedward-chaincoord/reference/setup/)
   (`rehearsal_ops_token`).
2. Provision a chain binary (e.g. `gaiad`) and a base64 Ed25519 service key (`coordd keygen`).
3. Run `rehearsald` with `coordd_url=http://localhost:8080`, the same `ops_token`, plus `binary_path` and
   `service_key_path`. It logs its **service public key** on startup.
4. When you create a launch in the UI, set its **`rehearsal_service_pubkey`** to that logged key and its
   **`rehearsal_endpoint`** to the daemon's URL — coordd then trusts (and, with the gate on, can require)
   its result facts.

See the [seedward-rehearsal README](https://github.com/ny4rl4th0t3p/seedward-rehearsal) for the full daemon
config.

## This repo

Besides the dev/demo stack (`docker/`, `Makefile`), this repo hosts the suite's cross-cutting
documentation site (`docs/` — MkDocs Material, Mermaid, MADR-format ADRs in `docs/decisions/`).
`make serve` previews it locally in an isolated `.venv`; it deploys to GitHub Pages via
`.github/workflows/docs.yml` on push to `main` (or `make deploy`).
