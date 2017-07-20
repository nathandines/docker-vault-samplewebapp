#!/bin/bash
cat <<EOF
ROLE-ID TOKEN
=============
EOF
vault read -wrap-ttl="5m" -format=json auth/approle/role/bachmanity_insanity-app/role-id
cat <<EOF
SECRET-ID TOKEN
=============
EOF
vault write -wrap-ttl="5m" -format=json -f auth/approle/role/bachmanity_insanity-app/secret-id
