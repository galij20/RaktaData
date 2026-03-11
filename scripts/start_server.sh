#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$repo_root/server/.env" && -f "$repo_root/server/.env.example" ]]; then
  cp "$repo_root/server/.env.example" "$repo_root/server/.env"
  echo "Created server/.env from server/.env.example (edit it before running in production)."
fi

cd "$repo_root/server"
npm install
npm run dev
