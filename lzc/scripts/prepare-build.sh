#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/lzc/pack"
tar -czf "$ROOT/lzc/pack/docs.tar.gz" -C "$ROOT/docs" .
