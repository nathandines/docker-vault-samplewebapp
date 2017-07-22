#!/bin/bash

pip install virtualenv
if [[ ! -d "venv" ]]; then
  virtualenv venv
fi
. venv/bin/activate
pip install -r ./requirements.txt

case $(uname -m) in
  x86_64) ARCH="amd64";;
esac

apt-get update && apt-get install -q unzip
wget -q "https://releases.hashicorp.com/vault/0.7.3/vault_0.7.3_linux_${ARCH}.zip" -O '/tmp/vault.zip' && \
  unzip '/tmp/vault.zip' -d '/usr/local/bin' && rm -f '/tmp/vault.zip'
wget -q "https://releases.hashicorp.com/consul-template/0.19.0/consul-template_0.19.0_linux_${ARCH}.zip" -O '/tmp/consul-template.zip' && \
  unzip '/tmp/consul-template.zip' -d '/usr/local/bin' && rm -f '/tmp/consul-template.zip'

export VAULT_ADDR='http://vault:8200'

VAULT_ROLE_ID="$(vault unwrap -field=role_id "$VAULT_ROLE_ID_TOKEN")"
VAULT_SECRET_ID="$(vault unwrap -field=secret_id "$VAULT_SECRET_ID_TOKEN")"
export VAULT_TOKEN="$(vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")"
consul-template &

# shellcheck disable=SC2068
python $@

kill -9 %1 # Kill consul-template
vault token-revoke -self
