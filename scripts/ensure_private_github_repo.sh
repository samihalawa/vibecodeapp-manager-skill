#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ensure_private_github_repo.sh [--dry-run] owner/repo [description]

Examples:
  ensure_private_github_repo.sh samihalawa/2026-VIBECODEAPP-promptpilot
  ensure_private_github_repo.sh --dry-run samihalawa/2026-VIBECODEAPP-posthog-native-kit "Vibecode workspace export"
EOF
}

dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
  dry_run=1
  shift
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

repo_spec="$1"
shift || true
description="${*:-Vibecode workspace export}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

owner="${repo_spec%%/*}"
repo="${repo_spec##*/}"

if gh repo view "$repo_spec" >/dev/null 2>&1; then
  echo "exists https://github.com/$repo_spec"
  exit 0
fi

if [[ "$dry_run" == "1" ]]; then
  echo "would-create https://github.com/$repo_spec"
  exit 0
fi

gh repo create "$owner/$repo" --private --description "$description"
echo "created https://github.com/$repo_spec"
