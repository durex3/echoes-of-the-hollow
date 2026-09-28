#!/usr/bin/env bash
set -u
root="$(cd "$(dirname "$0")" && pwd)"
cd "$root"

echo "Running Echoes of the Hollow checks..."
if ./tools/check.sh "$@"; then
    code=0
    echo
    echo "Checks passed. Press Return to close."
else
    code=$?
    echo
    echo "Checks failed with exit code $code. Logs are in artifacts/."
    echo "Press Return to close."
fi
read -r || true
exit "$code"
