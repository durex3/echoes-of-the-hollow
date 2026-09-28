#!/usr/bin/env bash
set -e
root="$(cd "$(dirname "$0")" && pwd)"
cd "$root"
exec ./tools/run.sh --editor "$@"
