#!/usr/bin/env bash
#
# seed.sh — populate a running coordd with the demo fixture.
#
# Pipeline: derive N accounts from DEMO_MNEMONIC via gaiad (BIP39 + Cosmos HD path), authenticate to
# coordd with ADR-036 (gaiad-exported raw hex → `smoke-signer sign --privkey-hex`), seed the
# coordinator allowlist, then build the launch fixture. mnemonic → gaiad (HD derive) → raw hex →
# smoke-signer → coordd; the same mnemonic imported into Keplr/Leap reproduces these addresses.
#
# Idempotency: expects a FRESH coordd volume — re-seed = `make dev-down` then up + `make dev-seed`.
#
# Env:
#   COORD_SERVER    coordd base URL              (default http://coordd:8080)
#   DEMO_MNEMONIC   BIP39 mnemonic (required)    — all accounts derive from this
#   HRP             bech32 prefix                (default cosmos; must match gaiad's config)
#   DERIVE_BY       "account" | "index"          (default account → m/44'/118'/i'/0/0, the BIP-44
#                   account index; to be account i in a wallet, set the derivation path's account
#                   field to i. "index" → m/44'/118'/0'/0/i varies the address index instead)
#   SEED_MODE       "full" | "accounts"          (default full; "accounts" prints the table and exits)
#   FIXTURES_DIR    fixture templates dir        (default /seed/fixtures — baked into the image)
set -euo pipefail
# Without inherit_errexit, $(...) subshells drop set -e — a failing rung inside fhash=$(assemble...)
# would keep running past the failure and hand the caller a bad artifact instead of aborting.
shopt -s inherit_errexit

COORD_SERVER="${COORD_SERVER:-http://coordd:8080}"
DEMO_MNEMONIC="${DEMO_MNEMONIC:?DEMO_MNEMONIC is required}"
HRP="${HRP:-cosmos}"
DERIVE_BY="${DERIVE_BY:-account}"
SEED_MODE="${SEED_MODE:-full}"
FIXTURES_DIR="${FIXTURES_DIR:-/seed/fixtures}"

KEYRING="test"
GAIA_HOME="/tmp/seed-gaia"
N_ACCOUNTS=16

# Roles by index (see docs/demo.md):
#   0 = admin + coordinator, 1 = coordinator, 2 = committee delegate (NOT a coordinator),
#   3-14 = validators, 15 = unauthorized.
IDX_ADMIN=0
COORDINATOR_INDICES=(0 1) # added to coordd's coordinator allowlist; idx 2 deliberately excluded.

declare -a ADDR   # ADDR[i]   = bech32 address of account i
declare -a HEXKEY # HEXKEY[i] = raw secp256k1 private key (hex) of account i
declare -A TOKEN  # TOKEN[i]  = cached coordd JWT for account i

# Genesis math. Equal self-delegation across validators keeps every operator below the 1/3 BFT
# threshold coordd enforces at window close — so closing launches need >= 4 approved validators.
DELEGATION="100000000"   # self-delegation each validator gentx stakes (matches smoke-test)
INIT_BALANCE="1000000000" # balance the coordinator assigns each validator in the final genesis

log() { echo "==> $*" >&2; }

# curl_check: curl wrapper that prints the response body to stderr on HTTP >= 400 (or a connection
# failure) and returns 1; on success echoes the body to stdout.
curl_check() {
  local tmp code
  tmp=$(mktemp)
  if ! code=$(curl -sS -o "$tmp" -w '%{http_code}' "$@"); then
    echo "ERROR: curl failed (network) for: $*" >&2
    rm -f "$tmp"
    return 1
  fi
  if [ "$code" -ge 400 ]; then
    echo "ERROR: HTTP $code for: $*" >&2
    cat "$tmp" >&2
    rm -f "$tmp"
    return 1
  fi
  cat "$tmp"
  rm -f "$tmp"
}

# expect_status <want> <desc> <curl args...>: assert a request returns HTTP <want> (for the negative
# role-boundary checks). Fails the seed loudly if it doesn't.
expect_status() {
  local want="$1" desc="$2"
  shift 2
  local code
  code=$(curl -sS -o /dev/null -w '%{http_code}' "$@")
  if [ "$code" = "$want" ]; then
    log "  OK: $desc ($code)"
  else
    echo "ASSERT FAIL: $desc — expected $want, got $code" >&2
    return 1
  fi
}

wait_for_coordd() {
  log "waiting for coordd at $COORD_SERVER ..."
  local i
  for i in $(seq 1 60); do
    if curl -sf "$COORD_SERVER/healthz" >/dev/null 2>&1; then
      log "coordd is up"
      return 0
    fi
    sleep 1
  done
  echo "TIMEOUT: coordd did not become healthy" >&2
  return 1
}

# derive_accounts: import each HD account into a throwaway gaiad keyring and capture its address +
# raw hex private key. gaiad does the standard Cosmos HD derivation, so the same mnemonic in
# Keplr/Leap reproduces these addresses (account 0 = the wallet's default import).
derive_accounts() {
  log "deriving $N_ACCOUNTS accounts from the demo mnemonic (derive-by=$DERIVE_BY) ..."
  rm -rf "$GAIA_HOME"
  mkdir -p "$GAIA_HOME"
  local i acct idx
  for ((i = 0; i < N_ACCOUNTS; i++)); do
    acct=0
    idx=0
    if [ "$DERIVE_BY" = "index" ]; then idx="$i"; else acct="$i"; fi
    printf '%s\n' "$DEMO_MNEMONIC" \
      | gaiad keys add "acct$i" --recover --account "$acct" --index "$idx" \
        --keyring-backend "$KEYRING" --home "$GAIA_HOME" >/dev/null 2>&1
    ADDR[i]=$(gaiad keys show "acct$i" -a \
      --keyring-backend "$KEYRING" --home "$GAIA_HOME")
    # `echo y` (finite) answers the --unsafe confirmation. `yes` would keep writing after gaiad
    # exits and die with SIGPIPE, which pipefail turns into a fatal 141. Merge streams and grep the
    # 64-hex key line so this works whether gaiad prints the key to stdout or stderr.
    HEXKEY[i]=$(echo "y" | gaiad keys export "acct$i" --unarmored-hex --unsafe \
      --keyring-backend "$KEYRING" --home "$GAIA_HOME" 2>&1 | grep -oE '[0-9a-fA-F]{64}' | head -n1 || true)
    if [ -z "${HEXKEY[i]}" ]; then
      echo "ERROR: could not export a hex private key for acct$i" >&2
      return 1
    fi
  done
}

# auth_token <index>: authenticate account <index> with coordd and echo its JWT. Signs the ADR-036
# challenge with the account's raw key via smoke-signer (--privkey-hex).
auth_token() {
  local i="$1" addr="${ADDR[$1]}" hex="${HEXKEY[$1]}"
  local challenge signed
  challenge=$(curl_check -X POST "$COORD_SERVER/auth/challenge" \
    -H 'Content-Type: application/json' \
    -d "{\"operator_address\":\"$addr\"}" | jq -r '.challenge')
  signed=$(printf \
    '{"operator_address":"%s","challenge":"%s","nonce":"","timestamp":"","pubkey_b64":"","signature":""}' \
    "$addr" "$challenge" | smoke-signer sign --privkey-hex "$hex")
  curl_check -X POST "$COORD_SERVER/auth/verify" \
    -H 'Content-Type: application/json' -d "$signed" | jq -r '.token'
}

# token_for <index>: cached JWT for account <index>. The cache MUST be pre-populated by
# prime_tokens: token_for is almost always called inside a $(...) command substitution (a subshell),
# and a subshell can read the inherited cache but cannot write it back — so an on-demand auth here
# would never persist and would re-auth on every call.
token_for() {
  local i="$1"
  if [ -z "${TOKEN[$i]:-}" ]; then TOKEN[$i]=$(auth_token "$i"); fi
  echo "${TOKEN[$i]}"
}

# prime_tokens: authenticate every acting account once, in the main shell, so token_for reads a
# populated cache. Account 15 (unauthorized) never authenticates.
prime_tokens() {
  log "authenticating demo accounts ..."
  local i
  for ((i = 0; i < N_ACCOUNTS - 1; i++)); do
    TOKEN[$i]=$(auth_token "$i")
  done
}

# seed_coordinators: as admin (idx 0), add the coordinator accounts to coordd's allowlist. Under
# launch_policy=restricted only these may create launches. idx 2 is intentionally NOT added — it can
# govern a launch (as a committee member) but cannot create one.
seed_coordinators() {
  log "seeding coordinator allowlist ..."
  local admin_token i
  admin_token=$(token_for "$IDX_ADMIN")
  for i in "${COORDINATOR_INDICES[@]}"; do
    curl_check -X POST "$COORD_SERVER/admin/coordinators" \
      -H "Authorization: Bearer $admin_token" \
      -H 'Content-Type: application/json' \
      -d "{\"address\":\"${ADDR[$i]}\"}" >/dev/null
    log "  + coordinator ${ADDR[$i]} (idx $i)"
  done
}

# role_of <index>: the demo role assigned to an account (see docs/demo.md). Kept in sync with
# IDX_ADMIN / COORDINATOR_INDICES above.
role_of() {
  case "$1" in
  0) echo "admin + coordinator" ;;
  1) echo "coordinator" ;;
  2) echo "committee delegate (no-create)" ;;
  15) echo "unauthorized" ;;
  *) echo "validator" ;;
  esac
}

# print_accounts: emit the credentials table (make dev-accounts → docs/demo.md).
print_accounts() {
  echo "# Demo accounts — derived from DEMO_MNEMONIC ($([ "$DERIVE_BY" = index ] && echo "m/44'/118'/0'/0/i" || echo "m/44'/118'/i'/0/0"))"
  echo "# WARNING: public throwaway mnemonic — insecure by design. Never reuse; never send real funds."
  printf '%-4s %-32s %-45s %s\n' "idx" "role" "address" "privkey_hex"
  local i
  for ((i = 0; i < N_ACCOUNTS; i++)); do
    printf '%-4s %-32s %-45s %s\n' "$i" "$(role_of "$i")" "${ADDR[$i]}" "${HEXKEY[$i]}"
  done
}

# --- launch ladder -------------------------------------------------------------------------------
# The reusable rungs, adapted from smoke-test.sh but signing with --privkey-hex and M-of-N aware.
# Per-launch gaiad homes live under $GAIA_HOME/l/<chain_id>/.

coord_home() { echo "$GAIA_HOME/l/$1/coord"; }
val_home() { echo "$GAIA_HOME/l/$1/val$2"; }

# propose_and_sign <launch_id> <action> <payload_json> <lead_idx> [cosigner_idx...]: raise a proposal
# as the lead (counts as its signature), then sign as each cosigner until it executes. A 1-of-1
# committee executes on the raise. Passing fewer cosigners than the threshold requires leaves it
# PENDING_SIGNATURES (used for the centerpiece demo). Echoes the proposal id.
propose_and_sign() {
  local launch_id="$1" action="$2" payload="$3" lead="$4"
  shift 4
  local lead_addr="${ADDR[$lead]}" lead_hex="${HEXKEY[$lead]}" lead_token
  lead_token=$(token_for "$lead")

  local raise signed resp pid pstatus
  raise=$(printf '{"member_address":"%s","action_type":"%s","payload":%s,"nonce":"","timestamp":"","pubkey_b64":"","signature":""}' \
    "$lead_addr" "$action" "$payload")
  signed=$(printf '%s' "$raise" | smoke-signer sign --privkey-hex "$lead_hex")
  resp=$(curl_check -X POST "$COORD_SERVER/launch/$launch_id/proposal" \
    -H "Authorization: Bearer $lead_token" -H 'Content-Type: application/json' -d "$signed")
  pid=$(echo "$resp" | jq -r '.id')
  pstatus=$(echo "$resp" | jq -r '.status')

  local s s_addr s_hex s_token s_tmpl s_signed
  for s in "$@"; do
    [ "$pstatus" = "PENDING_SIGNATURES" ] || break
    s_addr="${ADDR[$s]}"
    s_hex="${HEXKEY[$s]}"
    s_token=$(token_for "$s")
    s_tmpl=$(printf '{"member_address":"%s","decision":"SIGN","nonce":"","timestamp":"","pubkey_b64":"","signature":""}' "$s_addr")
    s_signed=$(printf '%s' "$s_tmpl" | smoke-signer sign --privkey-hex "$s_hex")
    resp=$(curl_check -X POST "$COORD_SERVER/launch/$launch_id/proposal/$pid/sign" \
      -H "Authorization: Bearer $s_token" -H 'Content-Type: application/json' -d "$s_signed")
    pstatus=$(echo "$resp" | jq -r '.status // "PENDING_SIGNATURES"')
  done
  echo "$pid"
}

# init_launch_genesis <chain_id> <denom>: init the coordinator's baseline genesis and patch the bond
# denom. Echoes the initial-genesis sha256.
init_launch_genesis() {
  local chain_id="$1" denom="$2" home g
  home=$(coord_home "$chain_id")
  rm -rf "$home"
  mkdir -p "$home"
  gaiad init coordinator --chain-id "$chain_id" --home "$home" >/dev/null 2>&1
  g="$home/config/genesis.json"
  jq --arg d "$denom" '
    .app_state.staking.params.bond_denom       = $d
    | .app_state.mint.params.mint_denom         = $d
    | .app_state.crisis.constant_fee.denom      = $d
    | .app_state.gov.params.min_deposit[0].denom = $d
  ' "$g" >"$g.tmp" && mv "$g.tmp" "$g"
  sha256sum "$g" | awk '{print $1}'
}

# validator_join <launch_id> <chain_id> <denom> <val_idx>: as validator <val_idx>, build a gentx
# against the launch genesis and submit a join request. Echoes the join_request_id.
validator_join() {
  local launch_id="$1" chain_id="$2" denom="$3" i="$4"
  local vhome chome op token gentx_file gentx_json node_id peer join signed
  vhome=$(val_home "$chain_id" "$i")
  chome=$(coord_home "$chain_id")
  op="${ADDR[$i]}"

  rm -rf "$vhome"
  mkdir -p "$vhome"
  gaiad init "val$i" --chain-id "$chain_id" --home "$vhome" >/dev/null 2>&1
  gaiad keys import-hex operator "${HEXKEY[$i]}" --keyring-backend "$KEYRING" --home "$vhome" >/dev/null 2>&1
  cp "$chome/config/genesis.json" "$vhome/config/genesis.json"
  gaiad genesis add-genesis-account "$op" "${DELEGATION}${denom}" --home "$vhome" >/dev/null 2>&1
  gaiad genesis gentx operator "${DELEGATION}${denom}" \
    --chain-id "$chain_id" --keyring-backend "$KEYRING" --home "$vhome" \
    --moniker "val$i" --commission-rate 0.05 --commission-max-rate 0.20 \
    --commission-max-change-rate 0.01 --min-self-delegation 1 >/dev/null 2>&1

  gentx_file=$(ls "$vhome/config/gentx/gentx-"*.json | head -1)
  gentx_json=$(cat "$gentx_file")
  node_id=$(gaiad comet show-node-id --home "$vhome" 2>/dev/null)
  peer="${node_id}@val$i:26656"

  token=$(token_for "$i")
  join=$(printf '{"operator_address":"%s","chain_id":"%s","gentx":%s,"peer_address":"%s","rpc_endpoint":"%s","memo":"","nonce":"","timestamp":"","pubkey_b64":"","signature":""}' \
    "$op" "$chain_id" "$gentx_json" "$peer" "http://val$i:26657")
  signed=$(printf '%s' "$join" | smoke-signer sign --privkey-hex "${HEXKEY[$i]}")
  curl_check -X POST "$COORD_SERVER/launch/$launch_id/join" \
    -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$signed" | jq -r '.id'
}

# assemble_final_genesis <launch_id> <chain_id> <denom> <lead_idx> "<approved_idxs>": coordinator
# funds the approved validators, collects their gentxs from coordd, builds + validates the final
# genesis. Echoes the final-genesis sha256.
assemble_final_genesis() {
  local launch_id="$1" chain_id="$2" denom="$3" lead="$4" approved="$5"
  local chome lead_token gt g vi
  chome=$(coord_home "$chain_id")
  lead_token=$(token_for "$lead")

  for vi in $approved; do
    gaiad genesis add-genesis-account "${ADDR[$vi]}" "${INIT_BALANCE}${denom}" --home "$chome" >/dev/null 2>&1 || true
  done

  mkdir -p "$chome/config/gentx"
  curl_check "$COORD_SERVER/launch/$launch_id/gentxs" -H "Authorization: Bearer $lead_token" \
    | jq -c '.gentxs[]' | while IFS= read -r entry; do
    jr=$(echo "$entry" | jq -r '.join_request_id')
    echo "$entry" | jq -c '.gentx' >"$chome/config/gentx/gentx-$jr.json"
  done

  gaiad genesis collect-gentxs --home "$chome" >/dev/null 2>&1
  # coordd requires genesis_time in the future at upload; keep it near-future (busybox-safe date).
  gt=$(date -u -d "@$(($(date +%s) + 120))" +"%Y-%m-%dT%H:%M:%SZ")
  g="$chome/config/genesis.json"
  jq --arg t "$gt" '.genesis_time = $t' "$g" >"$g.tmp" && mv "$g.tmp" "$g"
  gaiad genesis validate --home "$chome" >/dev/null 2>&1
  sha256sum "$g" | awk '{print $1}'
}

# assemble_final_genesis_gentool <launch_id> <chain_id> <denom> <lead_idx> "<approved_idxs>":
# gentool-based final assembly (the Echo showcase — custom accounts, vesting claims/grants, authz +
# feegrant, community pool). Renders the fixture templates under $FIXTURES_DIR/echo/ ({{ADDRi}} →
# derived addresses, times relative to now, total_supply computed from the rendered inputs), fetches
# the approved gentxs from coordd, runs `gentool create` against the launch's baseline genesis,
# validates with gaiad, and echoes the final-genesis sha256.
assemble_final_genesis_gentool() {
  local launch_id="$1" chain_id="$2" denom="$3" lead="$4" approved="$5"
  local chome fixdir gentx_dir out lead_token
  chome=$(coord_home "$chain_id")
  fixdir="$chome/gentool"
  gentx_dir="$fixdir/gentx"
  out="$fixdir/genesis.json"
  rm -rf "$fixdir"
  mkdir -p "$gentx_dir"
  lead_token=$(token_for "$lead")

  # approved gentxs from coordd — the same source of truth the collect-gentxs path uses.
  curl_check "$COORD_SERVER/launch/$launch_id/gentxs" -H "Authorization: Bearer $lead_token" \
    | jq -c '.gentxs[]' | while IFS= read -r entry; do
    jr=$(echo "$entry" | jq -r '.join_request_id')
    echo "$entry" | jq -c '.gentx' >"$gentx_dir/gentx-$jr.json"
  done

  # Seed-relative times keep the fixture always-runnable (nothing hardcoded that can go stale).
  local now gt_unix claims_end grants_start grants_end far_future
  now=$(date +%s)
  gt_unix=$((now + 120))          # genesis_time — coordd requires it to be future at upload
  claims_end=$((now + 31536000))  # +1y: the delayed-vesting cliff
  grants_start=$now               # continuous vesting is already unlocking at genesis
  grants_end=$((now + 63072000))  # +2y
  far_future=$((now + 63072000))  # authz / feegrant expiries

  # Render the templates. {{TOTAL_SUPPLY}} stays unresolved in gentool.yaml until the CSVs exist —
  # it is computed FROM them below, so editing fixture amounts keeps the supply check green.
  local f content i
  for f in accounts.csv claims.csv grants.csv authz.csv feegrant.csv gentool.yaml; do
    content=$(cat "$FIXTURES_DIR/echo/$f")
    for ((i = 0; i < N_ACCOUNTS; i++)); do
      content=${content//"{{ADDR$i}}"/"${ADDR[$i]}"}
    done
    content=${content//"{{CHAIN_ID}}"/"$chain_id"}
    content=${content//"{{DENOM}}"/"$denom"}
    content=${content//"{{GENESIS_TIME}}"/"$gt_unix"}
    content=${content//"{{CLAIMS_END}}"/"$claims_end"}
    content=${content//"{{GRANTS_START}}"/"$grants_start"}
    content=${content//"{{GRANTS_END}}"/"$grants_end"}
    content=${content//"{{FAR_FUTURE}}"/"$far_future"}
    content=${content//"{{FIXDIR}}"/"$fixdir"}
    content=${content//"{{GENTX_DIR}}"/"$gentx_dir"}
    content=${content//"{{OUTPUT}}"/"$out"}
    printf '%s\n' "$content" >"$fixdir/$f"
  done

  # gentool validates accounts.total_supply == everything that exists at genesis:
  # accounts + claims + grants + the gentx self-delegations (bonded pool) + the community pool.
  local acc_sum claims_sum grants_sum pool n_vals total
  acc_sum=$(awk -F, '{s += $2} END {printf "%.0f", s}' "$fixdir/accounts.csv")
  claims_sum=$(awk -F, '{s += $2} END {printf "%.0f", s}' "$fixdir/claims.csv")
  grants_sum=$(awk -F, '{s += $2} END {printf "%.0f", s}' "$fixdir/grants.csv")
  pool=$(awk '/community_pool_amount:/ {print $2 + 0}' "$fixdir/gentool.yaml")
  n_vals=$(echo "$approved" | wc -w)
  total=$((acc_sum + claims_sum + grants_sum + n_vals * DELEGATION + pool))
  content=$(cat "$fixdir/gentool.yaml")
  content=${content//"{{TOTAL_SUPPLY}}"/"$total"}
  printf '%s\n' "$content" >"$fixdir/gentool.yaml"

  log "    gentool: assembling $chain_id (total supply $total$denom)"
  gentool create --input-genesis "$chome/config/genesis.json" --config "$fixdir/gentool.yaml" >&2
  cp "$out" "$chome/config/genesis.json"
  gaiad genesis validate --home "$chome" >/dev/null
  sha256sum "$chome/config/genesis.json" | awk '{print $1}'
}

# build_launch <spec_assoc_array_name>: create a launch and walk it to spec[target]. Spec keys:
#   name chain_id denom type target(DRAFT|PUBLISHED|WINDOW_OPEN|WINDOW_CLOSED|GENESIS_READY|CANCELED)
#   creator(coordinator idx that POSTs /launch; default lead) lead(committee members[0])
#   committee(space-list of member idxs; first must be lead) threshold(M) cosign(extra signer idxs
#   for M-of-N proposals) min_validators allow(validator idxs) join(subset) approve(subset)
#   pending_last_approve(1 → leave the final APPROVE_VALIDATOR PENDING, for the centerpiece)
#   genesis(collect|gentool → final-genesis assembler; default collect-gentxs)
# Echoes the launch id.
build_launch() {
  local -n S="$1"
  local name="${S[name]}" chain_id="${S[chain_id]}" denom="${S[denom]:-ustake}" ltype="${S[type]}"
  local target="${S[target]}" lead="${S[lead]}" creator="${S[creator]:-${S[lead]}}"
  local threshold="${S[threshold]:-1}" minv="${S[min_validators]:-1}"
  local cosign="${S[cosign]:-}"
  log "launch: $name ($chain_id) → $target"

  # committee + allowlist JSON from indices
  local members_json="[]" allow_json="[]" m a total_n
  for m in ${S[committee]}; do
    members_json=$(echo "$members_json" | jq --arg a "${ADDR[$m]}" --arg mon "member$m" '. + [{address:$a,moniker:$mon}]')
  done
  # Add the demo admin (idx0) as an allowlisted VIEWER of every launch it doesn't already govern, so
  # the front-door account sees the whole fixture. Allowlist membership grants visibility + join, not
  # governance — safe: idx0 has no power over launches where it's only on the allowlist. (A creator
  # keeps sight of a launch it fully delegates by adding itself to the allowlist exactly like this.)
  local allow_idxs="${S[allow]:-}"
  case " ${S[committee]} " in
  *" $IDX_ADMIN "*) : ;;                    # already a committee member → already visible
  *) allow_idxs="$IDX_ADMIN $allow_idxs" ;; # add as a view-only member
  esac
  for a in $allow_idxs; do
    allow_json=$(echo "$allow_json" | jq --arg x "${ADDR[$a]}" '. + [$x]')
  done
  total_n=$(echo "${S[committee]}" | wc -w)

  # create (as the creator — must be an allowlisted coordinator under restricted policy)
  local creator_token id body
  creator_token=$(token_for "$creator")
  body=$(jq -n \
    --arg ct "$ltype" --argjson allow "$allow_json" --argjson members "$members_json" \
    --arg chain_id "$chain_id" --arg denom "$denom" --arg lead "${ADDR[$lead]}" \
    --argjson m "$threshold" --argjson n "$total_n" --argjson minv "$minv" \
    '{launch_type:$ct, allowlist:$allow,
      record:{chain_id:$chain_id, chain_name:$chain_id, bech32_prefix:"cosmos",
              binary_name:"gaiad", binary_version:"v27.1.0", denom:$denom,
              min_self_delegation:"1", max_commission_rate:"0.50", max_commission_change_rate:"0.10",
              gentx_deadline:"2099-01-01T00:00:00Z", genesis_time:"2099-01-01T00:00:00Z",
              min_validator_count:$minv},
      committee:{members:$members, threshold_m:$m, total_n:$n, lead_address:$lead}}')
  id=$(curl_check -X POST "$COORD_SERVER/launch" -H "Authorization: Bearer $creator_token" \
    -H 'Content-Type: application/json' -d "$body" | jq -r '.id')
  log "  created $id (DRAFT)"
  [ "$target" = "DRAFT" ] && {
    echo "$id"
    return 0
  }

  # everything past creation is a committee action → done by the lead (a committee member).
  local lead_token
  lead_token=$(token_for "$lead")

  # initial genesis + publish
  local ghash gfile
  ghash=$(init_launch_genesis "$chain_id" "$denom")
  gfile="$(coord_home "$chain_id")/config/genesis.json"
  curl_check -X POST "$COORD_SERVER/launch/$id/genesis?type=initial" \
    -H "Authorization: Bearer $lead_token" -H 'Content-Type: application/octet-stream' \
    --data-binary @"$gfile" >/dev/null
  propose_and_sign "$id" "PUBLISH_CHAIN_RECORD" "{\"initial_genesis_sha256\":\"$ghash\"}" "$lead" $cosign >/dev/null
  log "  PUBLISHED"

  if [ "$target" = "CANCELED" ]; then
    curl_check -X POST "$COORD_SERVER/launch/$id/cancel" -H "Authorization: Bearer $lead_token" >/dev/null
    log "  CANCELED"
    echo "$id"
    return 0
  fi
  [ "$target" = "PUBLISHED" ] && {
    echo "$id"
    return 0
  }

  # open window
  curl_check -X POST "$COORD_SERVER/launch/$id/open-window" -H "Authorization: Bearer $lead_token" >/dev/null
  log "  WINDOW_OPEN"

  # validators join
  local -A JR
  local vi
  for vi in ${S[join]:-}; do
    JR[$vi]=$(validator_join "$id" "$chain_id" "$denom" "$vi")
    log "    val$vi joined (jr ${JR[$vi]})"
  done

  # approve — optionally hold the last one back as a PENDING proposal (needs M>1 to stay pending)
  local approve="${S[approve]:-}" last=""
  if [ "${S[pending_last_approve]:-0}" = "1" ] && [ -n "$approve" ]; then
    last=$(echo "$approve" | awk '{print $NF}')
    approve=$(echo "$approve" | awk '{$NF=""; print}')
  fi
  for vi in $approve; do
    propose_and_sign "$id" "APPROVE_VALIDATOR" \
      "{\"join_request_id\":\"${JR[$vi]}\",\"operator_address\":\"${ADDR[$vi]}\"}" "$lead" $cosign >/dev/null
    log "    val$vi approved"
  done
  if [ -n "$last" ]; then
    propose_and_sign "$id" "APPROVE_VALIDATOR" \
      "{\"join_request_id\":\"${JR[$last]}\",\"operator_address\":\"${ADDR[$last]}\"}" "$lead" >/dev/null
    log "    val$last approval left PENDING (demo)"
  fi
  [ "$target" = "WINDOW_OPEN" ] && {
    echo "$id"
    return 0
  }

  # close window
  propose_and_sign "$id" "CLOSE_APPLICATION_WINDOW" "{}" "$lead" $cosign >/dev/null
  log "  WINDOW_CLOSED"
  [ "$target" = "WINDOW_CLOSED" ] && {
    echo "$id"
    return 0
  }

  # assemble + publish final genesis (spec key genesis=gentool swaps the assembler)
  local fhash
  if [ "${S[genesis]:-collect}" = "gentool" ]; then
    fhash=$(assemble_final_genesis_gentool "$id" "$chain_id" "$denom" "$lead" "${S[approve]}")
  else
    fhash=$(assemble_final_genesis "$id" "$chain_id" "$denom" "$lead" "${S[approve]}")
  fi
  curl_check -X POST "$COORD_SERVER/launch/$id/genesis?type=final" \
    -H "Authorization: Bearer $lead_token" -H 'Content-Type: application/octet-stream' \
    --data-binary @"$(coord_home "$chain_id")/config/genesis.json" >/dev/null
  propose_and_sign "$id" "PUBLISH_GENESIS" "{\"genesis_hash\":\"$fhash\"}" "$lead" $cosign >/dev/null
  log "  GENESIS_READY"
  echo "$id"
}

# demo_negative_checks <a_launch_id>: assert the role boundaries the fixture is meant to demonstrate.
demo_negative_checks() {
  local a_launch="$1"
  log "verifying role boundaries ..."
  # idx 2 (committee delegate) is NOT on the coordinator allowlist → cannot create under restricted
  # policy. coordd checks the allowlist before decoding the body, so an empty body still 403s.
  expect_status 403 "idx2 (delegate) cannot create a launch" \
    -X POST "$COORD_SERVER/launch" -H "Authorization: Bearer $(token_for 2)" \
    -H 'Content-Type: application/json' -d '{}'
  # idx 15 (unauthorized) is a member of nothing → a private launch is 404 even when authenticated.
  expect_status 404 "idx15 cannot see a private launch" \
    "$COORD_SERVER/launch/$a_launch" -H "Authorization: Bearer $(auth_token 15)"
}

# seed_launches: build the ~10-launch matrix on the ladder — one launch per reachable state plus
# type/committee variety. See docker/seeder/README.md for the full table.
seed_launches() {
  log "building launch fixture ..."

  # 1. Aurora — DRAFT (created, initial genesis uploaded, unpublished)
  local -A L_AURORA=(
    [name]="Aurora" [chain_id]="aurora-1" [denom]="uaurora" [type]="TESTNET"
    [target]="DRAFT" [lead]=1 [committee]="1" [threshold]=1 [min_validators]=1
  )
  build_launch L_AURORA >/dev/null

  # 2. Borealis — PUBLISHED (window not yet opened)
  local -A L_BOREALIS=(
    [name]="Borealis" [chain_id]="borealis-1" [denom]="uboreal" [type]="INCENTIVIZED_TESTNET"
    [target]="PUBLISHED" [lead]=1 [committee]="1" [threshold]=1 [min_validators]=1
  )
  build_launch L_BOREALIS >/dev/null

  # 3. Cascade — WINDOW_OPEN centerpiece: 2-of-3 committee LED by non-coordinator idx2 (created by
  #    coordinator idx1 — full delegation); idx6-8 allowlisted but unjoined (room to join); the last
  #    approval (val5) is left PENDING_SIGNATURES to show multisig governance in the UI.
  local -A L_CASCADE=(
    [name]="Cascade" [chain_id]="cascade-1" [denom]="umars" [type]="MAINNET"
    [target]="WINDOW_OPEN" [creator]=1 [lead]=2 [committee]="2 1 0" [threshold]=2 [cosign]="1"
    [min_validators]=3 [allow]="3 4 5 6 7 8" [join]="3 4 5" [approve]="3 4 5" [pending_last_approve]=1
  )
  local cascade_id
  cascade_id=$(build_launch L_CASCADE)

  # 4. Delta — WINDOW_CLOSED (4 approved, awaiting genesis)
  local -A L_DELTA=(
    [name]="Delta" [chain_id]="delta-1" [denom]="udelta" [type]="TESTNET"
    [target]="WINDOW_CLOSED" [lead]=1 [committee]="1" [threshold]=1 [min_validators]=4
    [allow]="3 4 9 10" [join]="3 4 9 10" [approve]="3 4 9 10"
  )
  build_launch L_DELTA >/dev/null

  # 5. Echo — GENESIS_READY, final genesis assembled with GENTOOL from custom inputs
  #    (fixtures/echo: treasury + ops accounts, delayed-vesting claims — one pre-delegated to val3 —
  #    a continuous-vesting grant, authz + feegrant seeds, and a community pool).
  local -A L_ECHO=(
    [name]="Echo" [chain_id]="echo-1" [denom]="uecho" [type]="MAINNET"
    [target]="GENESIS_READY" [lead]=0 [committee]="0" [threshold]=1 [min_validators]=4
    [allow]="3 4 5 11 12" [join]="3 4 5 11 12" [approve]="3 4 5 11 12"
    [genesis]="gentool"
  )
  build_launch L_ECHO >/dev/null

  # 6. Gale — CANCELED from PUBLISHED (committee lead idx2 cancels; created by coordinator idx1)
  local -A L_GALE=(
    [name]="Gale" [chain_id]="gale-1" [denom]="ugale" [type]="PERMISSIONED"
    [target]="CANCELED" [creator]=1 [lead]=2 [committee]="2" [threshold]=1 [min_validators]=1
  )
  build_launch L_GALE >/dev/null

  # 7. Halo — DRAFT (list/pagination variety)
  local -A L_HALO=(
    [name]="Halo" [chain_id]="halo-1" [denom]="uhalo" [type]="TESTNET"
    [target]="DRAFT" [lead]=1 [committee]="1" [threshold]=1 [min_validators]=1
  )
  build_launch L_HALO >/dev/null

  # 8. Ion — PUBLISHED, delegated (created by coordinator idx1, governed by non-coordinator idx2)
  local -A L_ION=(
    [name]="Ion" [chain_id]="ion-1" [denom]="uion" [type]="MAINNET"
    [target]="PUBLISHED" [creator]=1 [lead]=2 [committee]="2" [threshold]=1 [min_validators]=1
  )
  build_launch L_ION >/dev/null

  # 9. Juno — WINDOW_CLOSED (second closed example)
  local -A L_JUNO=(
    [name]="Juno" [chain_id]="juno-demo-1" [denom]="ujuno" [type]="INCENTIVIZED_TESTNET"
    [target]="WINDOW_CLOSED" [lead]=0 [committee]="0" [threshold]=1 [min_validators]=4
    [allow]="6 7 8 13" [join]="6 7 8 13" [approve]="6 7 8 13"
  )
  build_launch L_JUNO >/dev/null

  # 10. Kilo — WINDOW_OPEN (second open example; idx11-14 allowlisted but unjoined)
  local -A L_KILO=(
    [name]="Kilo" [chain_id]="kilo-1" [denom]="ukilo" [type]="TESTNET"
    [target]="WINDOW_OPEN" [lead]=1 [committee]="1" [threshold]=1 [min_validators]=1
    [allow]="9 10 11 12 13 14" [join]="9 10" [approve]="9 10"
  )
  build_launch L_KILO >/dev/null

  log "launch fixture done (10 launches)."
  demo_negative_checks "$cascade_id"
}

main() {
  derive_accounts
  if [ "$SEED_MODE" = "accounts" ]; then
    print_accounts
    exit 0
  fi
  wait_for_coordd
  prime_tokens
  seed_coordinators
  seed_launches
  log "seed complete."
}

main "$@"