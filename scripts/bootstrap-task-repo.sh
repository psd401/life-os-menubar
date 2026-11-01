#!/usr/bin/env bash
#
# Create the label definitions Life OS Menubar requires on a task repo.
#
# The app validates these labels; it never creates them (decision 0005). This
# script is the deliberate, reviewable bootstrap step that does.
#
# Usage:
#   scripts/bootstrap-task-repo.sh --repo owner/repo --dry-run   # print only
#   scripts/bootstrap-task-repo.sh --repo owner/repo             # create them
#
# Needs the GitHub CLI (`gh`) authenticated with write access to the repo.
# Re-running is safe: a label that already exists is left alone unless
# --force is passed, which overwrites its color and description with these.
# Any other failure (no write access, no such repo, network) is reported and
# the script exits non-zero.

set -euo pipefail

REPO=""
DRY_RUN=0
FORCE=0
FAILURES=0

usage() {
  sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --repo=*)
      REPO="${1#--repo=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h | --help)
      usage 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage 1
      ;;
  esac
done

if [ -z "$REPO" ]; then
  echo "error: --repo owner/repo is required" >&2
  usage 1
fi

if ! printf '%s' "$REPO" | grep -Eq '^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$'; then
  echo "error: --repo must be owner/repo, got \"$REPO\"" >&2
  exit 1
fi

# name|color|description — the required contract, matching
# LabelRules.requiredLabelNames in Sources/LifeOSMenubarCore/LabelRules.swift.
# "|" is the delimiter because every status and priority name contains a colon.
LABELS=(
  "status:inbox|B60205|Captured, not yet triaged"
  "status:next|0E8A16|Ready to work on next"
  "status:active|1D76DB|In progress right now"
  "status:waiting|FBCA04|Blocked on someone or something else"
  "status:scheduled|5319E7|Starts on a date"
  "status:someday|BFD4F2|Parked, no commitment"
  "status:done|0E8A16|Finished; the issue is closed"
  "priority:p0|B60205|Drop everything"
  "priority:p1|D93F0B|Important this week"
  "priority:p2|FBCA04|Default priority"
  "priority:p3|C5DEF5|Nice to have"
  "type:task|EDEDED|An actionable task"
  "source:manual|EDEDED|Created by a person, not an automation"
)

if [ "$DRY_RUN" -eq 0 ] && ! command -v gh >/dev/null 2>&1; then
  echo "error: the GitHub CLI (gh) is required; install it or use --dry-run" >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "# Dry run: no repository is contacted. Commands that would run:"
fi

for entry in "${LABELS[@]}"; do
  name="${entry%%|*}"
  rest="${entry#*|}"
  color="${rest%%|*}"
  description="${rest#*|}"

  args=(label create "$name" --repo "$REPO" --color "$color" --description "$description")
  if [ "$FORCE" -eq 1 ]; then
    args+=(--force)
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'gh'
    printf ' %q' "${args[@]}"
    printf '\n'
    continue
  fi

  if output=$(gh "${args[@]}" 2>&1); then
    if [ "$FORCE" -eq 1 ]; then
      echo "set     $name"
    else
      echo "created $name"
    fi
  elif printf '%s' "$output" | grep -q "already exists"; then
    echo "exists  $name (left as it is)"
  else
    echo "FAILED  $name: $output" >&2
    FAILURES=$((FAILURES + 1))
  fi
done

if [ "$DRY_RUN" -eq 0 ]; then
  echo
  if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES of ${#LABELS[@]} labels could not be created on $REPO (see FAILED above)." >&2
    echo "Check the repository name and that gh can write to it, then run this again." >&2
    exit 1
  fi
  echo "Done. Now enter $REPO in Life OS Menubar settings and validate it."
fi
