#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"


docker-compose up -d vault postgresql
echo -n 'Giving some time to the services to come online...'
# shellcheck disable=SC2034
for i in {1..20}; do
  echo -n '.'
  sleep 1
done
echo

. vault_env

# Enable Vault auditing
vault audit-enable file file_path=/vault/logs/audit_log

# Enable Approle authentication
vault auth-enable approle
vault policy-write bachmanity_insanity-app - <<'EOF'
path "database/creds/bachmanity_insanity-*" {
  policy = "read"
}
EOF
vault write auth/approle/role/bachmanity_insanity-app secret_id_num_uses=1 policies=bachmanity_insanity-app

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
        GRANT SELECT ON staff TO \"{{name}}\";" \
    default_ttl="1m" \
    max_ttl="1h"
vault write database/roles/bachmanity_insanity-readwrite \
    db_name=bachmanity_insanity \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON staff TO \"{{name}}\"; \
        GRANT USAGE, SELECT ON SEQUENCE staff_personid_seq TO \"{{name}}\";" \
    default_ttl="1m" \
    max_ttl="1h"
