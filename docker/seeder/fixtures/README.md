# Seeder fixtures

Static input **templates** for the demo seeder, copied into the image at `/seed/fixtures/`.

- `echo/` — custom genesis inputs for the **Echo** launch (#5, `GENESIS_READY`), assembled with
  `gentool`: `accounts.csv`, `claims.csv`, `grants.csv`, `authz.csv`, `feegrant.csv`, and
  `gentool.yaml`.

These are templates, not literal inputs — `seed.sh` renders them at seed time:

| Token                                                | Rendered as                                                        |
|------------------------------------------------------|--------------------------------------------------------------------|
| `{{ADDR<i>}}`                                        | account *i*'s address, derived from `DEMO_MNEMONIC` via gaiad      |
| `{{CHAIN_ID}}` `{{DENOM}}`                           | the launch spec's values                                           |
| `{{GENESIS_TIME}}`                                   | seed time + 120 s (unix — coordd requires a future genesis_time)   |
| `{{CLAIMS_END}}` `{{GRANTS_START}}` `{{GRANTS_END}}` | seed time +1y / now / +2y (vesting windows)                        |
| `{{FAR_FUTURE}}`                                     | seed time + 2y (authz / feegrant expiries)                         |
| `{{FIXDIR}}` `{{GENTX_DIR}}` `{{OUTPUT}}`            | per-launch working paths inside the container                      |
| `{{TOTAL_SUPPLY}}`                                   | computed from the rendered CSVs + gentx self-delegations + pool    |

Addresses are never hand-authored and times are always relative to the seed run, so the fixture
cannot go stale. Amounts CAN be edited freely — `{{TOTAL_SUPPLY}}` is recomputed from whatever the
rendered CSVs contain, keeping gentool's supply validation green.

Everything else the seeder needs is derived at run time (accounts from `DEMO_MNEMONIC`, gentxs via
gaiad), so nothing secret or environment-specific lives here.
