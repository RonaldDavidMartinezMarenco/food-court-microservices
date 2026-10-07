#!/usr/bin/env bash
# Clone the four service repositories into this master checkout.
# Each directory is its own Git repository. The master .gitignore leaves them out of this history.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

owner="RonaldDavidMartinezMarenco"
services=(
  user-service
  plaza-service
  traceability-service
  messaging-service
)

for name in "${services[@]}"; do
  if [[ -d "${name}/.git" ]]; then
    echo "${name}: already cloned"
    continue
  fi
  if [[ -e "$name" ]]; then
    echo "${name}: path exists and is not a Git checkout" >&2
    exit 1
  fi
  echo "${name}: cloning"
  git clone "https://github.com/${owner}/${name}.git" "$name"
done
