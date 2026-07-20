#!/bin/sh
set -e
# Auto-generate Ed25519 keys on first boot, then migrate and serve.
[ -f /data/audit_key ] || coordd keygen > /data/audit_key
[ -f /data/jwt_key ]   || coordd keygen > /data/jwt_key
coordd migrate
exec coordd serve