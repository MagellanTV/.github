#!/usr/bin/env bash
# ============================================================================
# Roll the PR review caller and the labeler out together, one PR per target.
#
#   ./scripts/rollout-pr-workflows.sh smart-tv magellantv-ios@develop apple-tv@v2
#   DRY_RUN=1 ./scripts/rollout-pr-workflows.sh smart-tv
#
# A target is a repository, optionally with @<branch>. Without a branch it uses
# the default branch. For each target the script compares
#
#   claude-review.caller.yml -> .github/workflows/claude-review.yml
#   labeler.caller.yml       -> .github/workflows/labeler.yml
#
# against what the target branch has, and opens one PR that adds or updates
# whichever is missing or different. A target where both already match is
# skipped. Nothing is merged automatically.
#
# Same SSH alias convention as rollout-claude-review.sh: GIT_HOST defaults to
# `MagellanTV`.
# ============================================================================
set -euo pipefail

ORG="MagellanTV"
GIT_HOST="${GIT_HOST:-MagellanTV}"
DRY_RUN="${DRY_RUN:-0}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# template:destination pairs
PAIRS=(
  "claude-review.caller.yml:.github/workflows/claude-review.yml"
  "labeler.caller.yml:.github/workflows/labeler.yml"
)

if [ $# -eq 0 ]; then
  echo "usage: $0 <repo>[@branch] [...]" >&2
  exit 1
fi

sha() { shasum -a 256 | cut -d' ' -f1; }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

for target in "$@"; do
  repo="${target%@*}"
  base=""
  [ "$target" != "$repo" ] && base="${target#*@}"

  echo "==> $ORG/$repo${base:+ @ $base}"

  if ! gh repo view "$ORG/$repo" >/dev/null 2>&1; then
    echo "    skipped: repository not accessible"
    continue
  fi
  [ -n "$base" ] || base="$(gh repo view "$ORG/$repo" --json defaultBranchRef --jq .defaultBranchRef.name)"

  needed=()
  for pair in "${PAIRS[@]}"; do
    tmpl="${pair%%:*}"; dest="${pair#*:}"
    remote="$(gh api "repos/$ORG/$repo/contents/$dest?ref=$base" --jq '.content' 2>/dev/null | tr -d '\n' || true)"
    if [ -n "$remote" ] && [ "$(echo "$remote" | base64 -d 2>/dev/null | sha)" = "$(sha < "$here/$tmpl")" ]; then
      continue
    fi
    needed+=("$pair")
  done

  if [ ${#needed[@]} -eq 0 ]; then
    echo "    skipped: both workflows already match the templates"
    continue
  fi

  branch="feature/pr-workflows"
  default="$(gh repo view "$ORG/$repo" --json defaultBranchRef --jq .defaultBranchRef.name)"
  [ "$base" != "$default" ] && branch="feature/pr-workflows-${base//\//-}"

  if git ls-remote --exit-code --heads "git@${GIT_HOST}:${ORG}/${repo}.git" "$branch" >/dev/null 2>&1; then
    echo "    skipped: branch $branch already exists on the remote"
    continue
  fi

  files="$(for p in "${needed[@]}"; do echo "${p#*:}"; done)"
  has_review=0; has_labeler=0
  echo "$files" | grep -q 'claude-review.yml' && has_review=1
  echo "$files" | grep -q 'labeler.yml' && has_labeler=1
  if [ $has_review = 1 ] && [ $has_labeler = 1 ]; then
    what="PR review and labeler workflows"
  elif [ $has_review = 1 ]; then
    what="PR review workflow"
  else
    what="labeler workflow"
  fi
  note=""
  [ $has_review = 1 ] && note="

This PR adds or changes the review workflow, so the review skips this PR: the workflow file differs from the base branch. It runs from the next PR after this one is merged."

  if [ "$DRY_RUN" = "1" ]; then
    echo "    dry run: would open $branch -> $base with:"
    echo "$files" | sed 's/^/      /'
    continue
  fi

  clone="$workdir/$repo-${base//\//-}"
  git clone --depth 1 --quiet --branch "$base" "git@${GIT_HOST}:${ORG}/${repo}.git" "$clone"
  (
    cd "$clone"
    git checkout -q -b "$branch"
    mkdir -p .github/workflows
    for p in "${needed[@]}"; do cp "$here/${p%%:*}" "${p#*:}"; git add "${p#*:}"; done
    git commit -q -m "ci: add the organization $what

Calls into MagellanTV/.github, where the configuration lives. Copied
unchanged from the template there."
    git push -q -u origin "$branch"
    gh pr create \
      --repo "$ORG/$repo" \
      --head "$branch" \
      --base "$base" \
      --title "ci: add the organization $what" \
      --body "Adds or updates the workflows every MagellanTV repository runs on pull requests:

$(echo "$files" | sed 's/^/- `/; s/$/`/')

Copied unchanged from the templates in [MagellanTV/.github](https://github.com/MagellanTV/.github), which holds the review configuration and the shared label rules.$note"
  )
  echo "    PR opened"
done
