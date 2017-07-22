#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

. vault_env

vault status
VAULT_ROOT_TOKEN="$(docker-compose logs vault | grep -oP '(?<=Root Token: )[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}' | tail -1)"

echo "Authenticating against Vault using root token ${VAULT_ROOT_TOKEN}..."
echo "$VAULT_ROOT_TOKEN" | vault auth -

export VAULT_ROLE_ID_TOKEN="$(vault read -wrap-ttl="5m" -field=wrapping_token auth/approle/role/bachmanity_insanity-app/role-id)"
export VAULT_SECRET_ID_TOKEN="$(vault write -wrap-ttl="5m" -field=wrapping_token -f auth/approle/role/bachmanity_insanity-app/secret-id)"

docker-compose up flaskapp
