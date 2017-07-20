#!/bin/bash

pip install virtualenv
virtualenv venv
. venv/bin/activate
pip install -r ./requirements.txt

# shellcheck disable=SC2068
python $@
