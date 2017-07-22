#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

. vault_env

export VAULT_ROLE_ID_TOKEN="$(vault read -wrap-ttl="5m" -field=wrapping_token auth/approle/role/bachmanity_insanity-app/role-id)"
export VAULT_SECRET_ID_TOKEN="$(vault write -wrap-ttl="5m" -field=wrapping_token -f auth/approle/role/bachmanity_insanity-app/secret-id)"

docker-compose up flaskapp
