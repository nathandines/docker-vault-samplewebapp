#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

. vault_env

docker-compose up -d
echo -n 'Giving some time to the services to come online...'
# shellcheck disable=SC2034
for i in {1..20}; do
  echo -n '.'
  sleep 1
done
echo

vault status
VAULT_ROOT_TOKEN="$(docker-compose logs vault | grep -oP '(?<=Root Token: )[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}' | tail -1)"

echo "Authenticating against Vault using root token ${VAULT_ROOT_TOKEN}..."
echo "$VAULT_ROOT_TOKEN" | vault auth -

# Enable Vault auditing
vault audit-enable file file_path=/vault/logs/audit_log

# This is a one-time execution per-DB
cat <<EOF
---
Configuring database secret backend to connect to the PostgreSQL docker
container using the credentials specified in stores/entrypoint-initdb.d/init-vault-user.sql

This initial database configuration would normally be executed securely by a DBA,
and the password discarded once configured in both the DB backend and Vault.

EOF
vault mount database
vault write database/config/bachmanity_insanity \
  plugin_name=postgresql-database-plugin \
  allowed_roles="bachmanity_insanity-readonly,bachmanity_insanity-readwrite" \
  connection_url="postgresql://vault:secret_password_for_vault@postgresql:5432/bachmanity_insanity?sslmode=disable"

cat <<EOF
---
Configuring roles for the bachmanity_insanity database. Credentials for this
database will be generated on-demand.

EOF
vault write database/roles/bachmanity_insanity-readonly \
    db_name=bachmanity_insanity \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON public.staff TO \"{{name}}\";" \
    default_ttl="1m" \
    max_ttl="1h"
vault write database/roles/bachmanity_insanity-readwrite \
    db_name=bachmanity_insanity \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.staff TO \"{{name}}\";" \
    default_ttl="1m" \
    max_ttl="1h"
