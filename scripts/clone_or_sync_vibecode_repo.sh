#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  clone_or_sync_vibecode_repo.sh <repo-url> <target-dir> [branch]

Examples:
  clone_or_sync_vibecode_repo.sh https://github.com/samihalawa/2026-VIBECODEAPP-promptpilot.git /Users/samihalawa/git/PROJECTS_VIBECODEAPP/2026-VIBECODEAPP-promptpilot
  clone_or_sync_vibecode_repo.sh git@github.com:samihalawa/2026-VIBECODEAPP-posthog-native-kit.git /Users/samihalawa/git/PROJECTS_VIBECODEAPP/2026-VIBECODEAPP-posthog-native-kit main
EOF
}

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

repo_url="$1"
target_dir="$2"
branch="${3:-main}"

if [[ ! -d "$target_dir/.git" ]]; then
  mkdir -p "$(dirname "$target_dir")"
  git clone "$repo_url" "$target_dir"
fi

git -C "$target_dir" remote get-url origin >/dev/null 2>&1 || git -C "$target_dir" remote add origin "$repo_url"
git -C "$target_dir" remote set-url origin "$repo_url"
git -C "$target_dir" fetch origin

if git -C "$target_dir" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$target_dir" checkout "$branch"
else
  git -C "$target_dir" checkout -B "$branch"
fi

if git -C "$target_dir" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  git -C "$target_dir" merge --ff-only "origin/$branch"
fi

git -C "$target_dir" remote -v
git -C "$target_dir" log --oneline -1 || true
