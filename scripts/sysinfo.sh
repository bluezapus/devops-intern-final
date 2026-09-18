#!/usr/bin/env bash
set -euo pipefail

echo "=== System Information ==="

echo "User: $(id -un)"
echo "Effective UID: $(id -u)"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Date: $(date --iso-8601=seconds)"

echo
echo "=== Disk Usage ==="
df -h

echo
echo "=== Memory Usage ==="
free -h

echo
echo "=== Docker Daemon ==="

if docker info >/dev/null 2>&1; then
    echo "Docker daemon: running"
else
    echo "Docker daemon: not running or inaccessible"
fi