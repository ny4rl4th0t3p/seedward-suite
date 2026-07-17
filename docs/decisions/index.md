# Decisions

Architecture Decision Records (ADRs) in [MADR](https://adr.github.io/madr/) format — one file per
decision, numbered, and **immutable once accepted** (supersede with a new ADR rather than editing). They
capture *why* the suite is shaped the way it is.

To add one: copy [`adr-template.md`](adr-template.md) to `NNNN-short-slug.md`, fill it in, and add it to
the `nav` in `mkdocs.yml`.

## Index

> ADR **numbers are stable identifiers** assigned in curation order — they are *not* chronological, and
> (by ADR convention) are never reused or renumbered. The table is **sorted by decision date** for a true
> timeline; new ADRs append with the next free number.

| ADR                                                    | Title                                                                                 | Decided    | Status   |
|--------------------------------------------------------|---------------------------------------------------------------------------------------|------------|----------|
| [0009](0009-launch-lifecycle-state-machine.md)         | Launch lifecycle is a guarded state machine                                           | 2026-04-10 | accepted |
| [0010](0010-m-of-n-committee-proposal-governance.md)   | Governance actions are M-of-N committee proposals                                     | 2026-04-10 | accepted |
| [0019](0019-readiness-attestation.md)                  | Validators attest readiness by signing against the final genesis hash                 | 2026-04-15 | accepted |
| [0011](0011-adr036-challenge-response-auth.md)         | Authentication is ADR-036 challenge-response; the address is the identity             | 2026-05-01 | accepted |
| [0017](0017-tamper-evident-audit-log.md)               | The audit log is a tamper-evident, hash-chained, signed append-only record            | 2026-05-15 | accepted |
| [0004](0004-gentool-library-first-genesis-engine.md)   | gentool is a library-first genesis engine                                             | 2026-06-08 | accepted |
| [0006](0006-rehearsal-engine-in-gentool.md)            | The rehearsal engine (`pkg/rehearse`) lives in gentool, coordd-agnostic               | 2026-06    | accepted |
| [0001](0001-single-gentx-validator-boundary.md)        | Gentx validation is a pure single-gentx library; cross-request checks live in coordd  | 2026-06-10 | accepted |
| [0002](0002-client-side-gentx-validation-wasm.md)      | gentxvalidate ships to the browser as WASM for client-side advisory validation        | 2026-06-10 | accepted |
| [0018](0018-artifact-storage-attestor-or-host.md)      | Large artifacts are attestor-referenced or host bytes — coordd never holds them       | 2026-06-10 | accepted |
| [0005](0005-gentool-mountable-command-tree.md)         | gentool commands are mountable into a host CLI                                        | 2026-06-11 | accepted |
| [0022](0022-suite-topology-naming-composition.md)      | Suite topology, naming, and composition                                               | 2026-06-11 | accepted |
| [0016](0016-pre-acceptance-gentx-validation.md)        | Gentxs are validated at submission with the shared library, server-grade              | 2026-06-18 | accepted |
| [0014](0014-allocation-files-whole-file-governance.md) | Genesis allocations are governed as whole, committee-approved files                   | 2026-06-20 | accepted |
| [0015](0015-input-set-hash.md)                         | `input_set_hash` — the fingerprint binding a genesis/rehearsal to its approved inputs | 2026-06-25 | accepted |
| [0013](0013-submitter-validator-identity-split.md)     | Join request has two identities: hot submitter, cold validator operator               | 2026-06-29 | accepted |
| [0020](0020-openapi-source-of-truth.md)                | The OpenAPI spec is the source of truth for the coordd API                            | 2026-07-01 | accepted |
| [0007](0007-bridge-fact-based-trust-boundary.md)       | The coordd↔rehearsal bridge is an ops-plane, fact-based trust boundary                | 2026-07-03 | accepted |
| [0008](0008-rehearsal-write-back-and-lease.md)         | Rehearsal result write-back: coordd-minted attempts + claim-before-run lease          | 2026-07-04 | accepted |
| [0012](0012-private-always-membership-visibility.md)   | Launches are private-always; visibility is committee ∪ members                        | 2026-07-05 | accepted |
| [0021](0021-web-standalone-spec-consuming-repo.md)     | The web control panel is a standalone repo generated from coordd's spec               | 2026-07-06 | accepted |
| [0003](0003-rehearsal-optional-bolt-on.md)             | Rehearsal is an optional bolt-on; coordd runs standalone                              | 2026-07-07 | accepted |
| [0023](0023-license-apache-2-0.md)                     | The suite is Apache-2.0 across all components (v1)                                    | 2026-07-08 | accepted |
| [0024](0024-hrp-independent-account-identity.md)       | The hot identity is the HRP-independent account                                       | 2026-07-08 | accepted |
| [0025](0025-cancel-governance-hybrid.md)               | Cancellation is stage-dependent (hybrid governance)                                   | 2026-07-16 | accepted |
| [0026](0026-coordinator-vs-committee-member.md)        | "Coordinator" (creator) vs "committee member" (in-launch seat)                        | 2026-07-16 | accepted |

## Backlog (candidate ADRs)

Decisions already made in the codebase, worth promoting to their own ADR here:

- **Genesis ↔ approved-set consistency** — a published genesis must match the approved set it was built
  from. Largely captured by [ADR-0015](0015-input-set-hash.md) + the genesis-finalization decisions;
  promote to a standalone ADR if it warrants its own record.