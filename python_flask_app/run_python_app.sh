#!/bin/bash

pip install virtualenv
if [[ ! -d "venv" ]]; then
  virtualenv venv
fi
. venv/bin/activate
pip install -r ./requirements.txt

# shellcheck disable=SC2068
python $@
