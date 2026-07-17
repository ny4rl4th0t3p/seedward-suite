# Launch flow across the suite

How a launch moves end-to-end. The [lifecycle state machine](../decisions/0009-launch-lifecycle-state-machine.md)
is coordd's; this page shows where each *component* acts along it.

## The actors

- **coordd** (mandatory) — owns the launch record + state machine, committee governance, gentx intake,
  allocation governance, and the audit log.
- **A coordinator** (human, via the web) — creates the launch and declares its committee; need not sit on it.
- **Committee members** (human, via the web) — the M-of-N who govern the launch via proposals; any of them can
  assemble the final genesis locally with **gentool** for the committee to approve. The **lead** (`Members[0]`)
  additionally holds the early-stage direct cancel.
- **Validators** (human, via the web) — submit gentx join requests and confirm readiness.
- **rehearsald** (optional) — pre-flights the assembled genesis on an ephemeral chain and writes back a
  signed fact.
- **gentool** — builds genesis (embedded in rehearsal; run standalone by a committee member for the final
  artifact).

## The flow

1. **DRAFT** — a coordinator creates the launch in coordd (chain params, committee, policy) and uploads
   the initial (pre-gentx) genesis. The web signs every action via ADR-036
   ([ADR-0011](../decisions/0011-adr036-challenge-response-auth.md)).
2. **PUBLISHED → WINDOW_OPEN** — a `PUBLISH_CHAIN_RECORD` proposal
   ([ADR-0010](../decisions/0010-m-of-n-committee-proposal-governance.md)) publishes the chain record; any
   committee member then **directly** opens the application window (`OpenWindow`, which auto-publishes from
   DRAFT when the initial genesis is present).
3. **Join** — validators submit gentxs; coordd validates each at the door with the shared
   `gentxvalidate.RunAll` ([ADR-0016](../decisions/0016-pre-acceptance-gentx-validation.md)) and derives
   the cold operator identity ([ADR-0013](../decisions/0013-submitter-validator-identity-split.md)). The
   committee approves gentxs and uploads/approves allocation files (whole-file,
   [ADR-0014](../decisions/0014-allocation-files-whole-file-governance.md)).
4. **WINDOW_CLOSED** — a committee member assembles the **final genesis** locally with gentool (coordd never
   assembles it — [ADR-0004](../decisions/0004-gentool-library-first-genesis-engine.md)) and uploads it
   (attestor ref or host bytes — [ADR-0018](../decisions/0018-artifact-storage-attestor-or-host.md)).
   coordd binds the `input_set_hash` ([ADR-0015](../decisions/0015-input-set-hash.md)) — the fingerprint of
   chain params + approved gentxs + allocation hashes.
5. **Rehearsal (optional)** — rehearsald pulls the approved input set over the ops-plane bridge
   ([ADR-0007](../decisions/0007-bridge-fact-based-trust-boundary.md)), boots an ephemeral
   substituted-validator chain, and writes back a signed pass/fail **fact** bound to that `input_set_hash`
   ([ADR-0008](../decisions/0008-rehearsal-write-back-and-lease.md)).
6. **GENESIS_READY** — a `PUBLISH_GENESIS` proposal executes. If the **rehearsal gate** is enabled
   ([ADR-0003](../decisions/0003-rehearsal-optional-bolt-on.md)), coordd consults the rehearsal fact for
   the current input set before allowing the transition; otherwise the fact is advisory.
7. **Readiness** — validators sign readiness confirmations against the final genesis hash
   ([ADR-0019](../decisions/0019-readiness-attestation.md)); the dashboard aggregates voting power toward
   the launch-go threshold.
8. **LAUNCHED** — coordd's block monitor sees the chain's first block on the configured RPC and marks the
   launch terminal.

Throughout, every state change is a signed, hash-chained entry in the tamper-evident audit log
([ADR-0017](../decisions/0017-tamper-evident-audit-log.md)), and the two planes stay separate: the
**governance plane** (wallet signing in the web) and the **ops plane** (deploy-time credentials for the
rehearsal bridge).
