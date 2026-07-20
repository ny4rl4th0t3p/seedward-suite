# Seeder fixtures

Static inputs for the demo seeder, copied into the image at `/seed/fixtures/`.

- `echo/` — custom genesis inputs for the **Echo** launch (#5, `GENESIS_READY`), assembled with
  `gentool`: `accounts.csv`, `claims.csv`, `grants.csv`, optional `authz.csv`/`feegrant.csv`, and
  `gentool.yaml`. Added in task 5.

Everything else the seeder needs is derived at run time (accounts from `DEMO_MNEMONIC`, gentxs via
gaiad), so nothing secret or environment-specific lives here.