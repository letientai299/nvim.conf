#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

for df in docker/*.Dockerfile; do
  name=$(basename "$df" .Dockerfile)
  echo "=== Testing on $name ==="
  docker build -f "$df" -t "nvim-test-$name" .
  docker run --rm -v "$(cd .. && pwd)":/opt/nvim-conf:ro \
    "nvim-test-$name" bash /opt/nvim-conf/tests/run.sh
done
