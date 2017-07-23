#!/bin/bash

pip install virtualenv
if [[ ! -d "venv" ]]; then
  virtualenv venv
fi
. venv/bin/activate
pip install -r ./requirements.txt

VAULT_VERSION="${VAULT_VERSION:-0.7.3}"
CT_VERSION="${CT_VERSION:-0.19.0}"

case $HOSTTYPE in
  x86_64) ARCH="amd64";;
  i?86) ARCH="386";;
  armv?l) ARCH="arm";;
esac

case $OSTYPE in
  darwin*) OS="darwin";;
  linux*) OS="linux";;
esac

apt-get update && apt-get install -q unzip
wget -q "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_${OS}_${ARCH}.zip" -O '/tmp/vault.zip' && \
  unzip '/tmp/vault.zip' -d '/usr/local/bin' && rm -f '/tmp/vault.zip'
wget -q "https://releases.hashicorp.com/consul-template/${CT_VERSION}/consul-template_${CT_VERSION}_${OS}_${ARCH}.zip" -O '/tmp/consul-template.zip' && \
  unzip '/tmp/consul-template.zip' -d '/usr/local/bin' && rm -f '/tmp/consul-template.zip'

export VAULT_ADDR='http://vault:8200'

VAULT_ROLE_ID="$(vault unwrap -field=role_id "$VAULT_ROLE_ID_TOKEN")"
VAULT_SECRET_ID="$(vault unwrap -field=secret_id "$VAULT_SECRET_ID_TOKEN")"
export VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")"
consul-template &
CT_PID=$!

# shellcheck disable=SC2068
python $@

kill -9 $CT_PID # Kill consul-template
vault token-revoke -self
