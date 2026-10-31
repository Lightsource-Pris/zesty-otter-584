#!/bin/bash
# One-time local setup. Safe to run again: every step skips what is already done.
# Secrets are written only to the git-ignored .env in this directory and never leave this machine.
set -euo pipefail
cd "$(dirname "$0")"

GRADER=task/tests/etask_grade.py
step() { printf '\n==> %s\n' "$1"; }
fail() { printf 'setup: %s\n' "$1" >&2; exit 1; }

step "Python 3.11+"
command -v python3 >/dev/null || fail "python3 not found; install Python 3.11 or newer"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' \
  || fail "python3 is $(python3 --version 2>&1); the grader needs 3.11 or newer"
python3 --version

step "uv"
if ! command -v uv >/dev/null; then
  echo "Installing uv from astral.sh"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
uv --version

step "Harbor (pinned to the verifier's version)"
HARBOR_VERSION="0.24.0"  # = HARBOR_VERSION in the verifier's grader
uvx --from "harbor==${HARBOR_VERSION}" harbor --version

step "Container runtime"
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  echo "docker is running"
elif command -v podman >/dev/null; then
  if ! podman info >/dev/null 2>&1; then
    fail "podman is installed but not running; start it (macOS: podman machine start) and rerun"
  fi
  echo "podman is running; ./check.sh uses it when docker is absent (or set ETASK_HARBOR_ENV=podman)"
else
  fail "install Docker or Podman, then rerun"
fi

step "Secrets (.env)"
if [ -d .git ] && ! git check-ignore -q .env; then
  echo ".env" >> .gitignore
  echo "added .env to .gitignore"
fi
touch .env
chmod 600 .env
missing=()
while IFS=$'\t' read -r name requirement description; do
  if grep -q "^${name}=." .env; then
    echo "${name}: already set"
    continue
  fi
  if ! { : < /dev/tty; } 2>/dev/null; then
    missing+=("${name} (${requirement})")
    continue
  fi
  printf '\n%s (%s)\n%s\nValue (input hidden, Enter to skip): ' "$name" "$requirement" "$description"
  read -rs value < /dev/tty || value=""
  echo
  if [ -n "$value" ]; then
    [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
    printf '%s=%s\n' "$name" "$value" >> .env
    echo "${name}: saved to .env"
  elif [ "$requirement" = "required" ]; then
    missing+=("${name} (required)")
  fi
done < <(python3 -c '
import json
for secret in json.load(open("secrets.manifest.json")):
    print(secret["name"], "required" if secret["required"] else "optional", secret["description"], sep="\t")
')
if [ ${#missing[@]} -gt 0 ]; then
  echo "Not set yet: ${missing[*]}. Add each as NAME=value in .env."
fi

step "Task checks"
if [ -f "$GRADER" ]; then
  python3 "$GRADER" validate --task-dir task
else
  echo "Skipped: $GRADER is missing. Ask your coding agent to fetch it with the Askable MCP tool agentic_coding_get_grader."
fi

if [ -f "$GRADER" ]; then
  printf '\nSetup done. Next: ./check.sh (oracle must score 1, nop must score 0).\n'
else
  printf '\nSetup done. Next: fetch the grader, then ./check.sh.\n'
fi
