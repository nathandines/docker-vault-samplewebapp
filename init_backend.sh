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
vault policy-write people_list-app - <<'EOF'
path "database/creds/people_list-*" {
  policy = "read"
}
EOF
vault write auth/approle/role/people_list-app token_ttl=1m token_ttl_max=1m policies=people_list-app

# This is a one-time execution per-DB
cat <<EOF
---
Configuring database secret backend to connect to the PostgreSQL docker
container using the credentials specified in stores/entrypoint-initdb.d/init-vault-user.sql

This initial database configuration would normally be executed securely by a DBA,
and the password discarded once configured in both the DB backend and Vault.

EOF
vault mount database
vault write database/config/people_list \
  plugin_name=postgresql-database-plugin \
  allowed_roles="people_list-readonly,people_list-readwrite" \
  connection_url="postgresql://vault:secret_password_for_vault@postgresql:5432/people_list?sslmode=disable"

cat <<EOF
---
Configuring roles for the people_list database. Credentials for this
database will be generated on-demand.

EOF
vault write database/roles/people_list-readonly \
    db_name=people_list \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON staff TO \"{{name}}\";" \
    default_ttl="1m" \
    max_ttl="1m"
vault write database/roles/people_list-readwrite \
    db_name=people_list \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON staff TO \"{{name}}\"; \
        GRANT USAGE, SELECT ON SEQUENCE staff_personid_seq TO \"{{name}}\";" \
    default_ttl="1m" \
    max_ttl="1m"
