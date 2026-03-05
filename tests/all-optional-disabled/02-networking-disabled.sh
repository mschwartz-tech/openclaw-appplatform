#!/bin/bash
# Test: Networking services disabled
# Verifies Tailscale is not running when disabled

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing networking disabled (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Tailscale should NOT be running (process and service)
assert_process_not_running "$CONTAINER" "tailscaled" || exit 1
assert_service_down "$CONTAINER" "tailscale" || exit 1

echo "Networking disabled tests passed"
