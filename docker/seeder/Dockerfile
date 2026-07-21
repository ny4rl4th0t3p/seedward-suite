# syntax=docker/dockerfile:1
#
# Demo seeder image — populates a running coordd with the demo fixture.
# Bundles: gaiad (BIP39/HD derivation + gentx), smoke-signer (coordd ADR-036 auth from a raw key),
# gentool (custom genesis assembly), and seed.sh. Built locally by `make dev-seed`; not published.

# --- Build the Go tools from pinned releases (portable: fetched from the module proxy, no sibling
#     checkout). CHAINCOORD_REF must carry smoke-signer's --privkey-hex (chaincoord >= v1.0.0);
#     point it at a branch/commit to build against unreleased changes.
FROM golang:1.25-alpine AS gobuild
RUN apk add --no-cache git
ARG CHAINCOORD_REF=v1.0.0
ARG GENTOOL_VERSION=v1.0.0
RUN go install "github.com/ny4rl4th0t3p/seedward-chaincoord/cmd/smoke-signer@${CHAINCOORD_REF}"
RUN go install "github.com/ny4rl4th0t3p/seedward-gentool/cmd/gentool@${GENTOOL_VERSION}"

# --- Fetch gaiad (same statically-linked release the chaincoord smoke image uses).
FROM alpine:3.20 AS gaiad-fetcher
ARG GAIA_VERSION=v27.1.0
RUN apk add --no-cache curl
RUN curl -fsSL \
  "https://github.com/cosmos/gaia/releases/download/${GAIA_VERSION}/gaiad-${GAIA_VERSION}-linux-amd64" \
  -o /bin/gaiad && chmod +x /bin/gaiad

# --- Runtime.
FROM alpine:3.20
RUN apk add --no-cache bash jq curl coreutils ca-certificates
COPY --from=gobuild       /go/bin/smoke-signer /usr/local/bin/smoke-signer
COPY --from=gobuild       /go/bin/gentool      /usr/local/bin/gentool
COPY --from=gaiad-fetcher /bin/gaiad           /usr/local/bin/gaiad
COPY fixtures/ /seed/fixtures/
COPY seed.sh /usr/local/bin/seed.sh
RUN chmod +x /usr/local/bin/seed.sh
ENTRYPOINT ["bash", "/usr/local/bin/seed.sh"]
