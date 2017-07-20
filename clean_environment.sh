#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

docker-compose stop
find stores/postgresql/data -mindepth 1 -maxdepth 1 -type d -exec rm -rf '{}' +
docker-compose rm -f
