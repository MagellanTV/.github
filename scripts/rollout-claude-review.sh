#!/usr/bin/env bash
# ============================================================================
# Roll the Claude PR review caller out to one or more repositories.
#
#   ./scripts/rollout-claude-review.sh smart-tv
#   ./scripts/rollout-claude-review.sh smart-tv newui-web magellantv_roku
#   DRY_RUN=1 ./scripts/rollout-claude-review.sh smart-tv
#
# A repository whose caller already matches the template is skipped; one whose
# caller has drifted, or predates a template change, is updated. Override the
# branch and the wording for a retrofit:
#
#   ROLLOUT_BRANCH=feature/claude-review-synchronize \
#   COMMIT_SUBJECT="re-review on every push" \
#   COMMIT_BODY="..." PR_INTRO="..." ./scripts/rollout-claude-review.sh <repos>
#
# Opens a pull request per repository. Nothing is merged automatically.
# Requires: gh, authenticated with write access to the target repositories.
# ============================================================================
set -euo pipefail

ORG="MagellanTV"
BRANCH="${ROLLOUT_BRANCH:-feature/claude-pr-review}"

# SSH host to clone through. Defaults to the `MagellanTV` alias, because these
# repositories are normally cloned that way and the alias selects the key with
# write access. `gh repo clone` would use plain github.com, which on a machine
# with several GitHub accounts can resolve to a read-only identity and fail at
# push time. Override with GIT_HOST=github.com if your default key is the
# right one.
GIT_HOST="${GIT_HOST:-MagellanTV}"
TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/claude-review.caller.yml"
DRY_RUN="${DRY_RUN:-0}"

if [ $# -eq 0 ]; then
  echo "usage: $0 <repo> [repo...]" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "template not found: $TEMPLATE" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

for repo in "$@"; do
  echo "==> $ORG/$repo"

  if ! gh repo view "$ORG/$repo" >/dev/null 2>&1; then
    echo "    skipped: repository not accessible"
    continue
  fi

  # Three cases: no caller yet (add it), a caller that already matches the
  # template (nothing to do), or a caller that has drifted or predates a
  # template change (update it). The third is what a retrofit looks like, and
  # the script used to treat it as the second and quietly do nothing.
  remote_b64="$(gh api "repos/$ORG/$repo/contents/.github/workflows/claude-review.yml" --jq '.content' 2>/dev/null | tr -d '\n' || true)"
  if [ -n "$remote_b64" ]; then
    if [ "$(echo "$remote_b64" | base64 -d 2>/dev/null | shasum -a 256 | cut -d' ' -f1)" \
       = "$(shasum -a 256 < "$TEMPLATE" | cut -d' ' -f1)" ]; then
      echo "    skipped: caller already matches the template"
      continue
    fi
    action_verb="update"
  else
    action_verb="add"
  fi

  if git ls-remote --exit-code --heads "git@${GIT_HOST}:${ORG}/${repo}.git" "$BRANCH" >/dev/null 2>&1; then
    echo "    skipped: branch $BRANCH already exists on the remote"
    continue
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "    dry run: would $action_verb .github/workflows/claude-review.yml and open a PR"
    continue
  fi

  clone="$workdir/$repo"
  git clone --depth 1 --quiet "git@${GIT_HOST}:${ORG}/${repo}.git" "$clone"

  (
    cd "$clone"
    base="$(gh repo view "$ORG/$repo" --json defaultBranchRef --jq .defaultBranchRef.name)"
    git checkout -q -b "$BRANCH"
    mkdir -p .github/workflows
    cp "$TEMPLATE" .github/workflows/claude-review.yml
    git add .github/workflows/claude-review.yml
    git commit -q -m "ci: ${COMMIT_SUBJECT:-enable organization Claude PR review}

${COMMIT_BODY:-Adds the caller for MagellanTV/.github/.github/workflows/org-claude-review.yml.
Prompt, review guidelines, model and cost controls stay centralized in the
organization .github repository.}"
    git push -q -u origin "$BRANCH"
    # --repo and --head are explicit because the remote is an SSH alias that gh
    # cannot resolve back to a GitHub repository on its own.
    gh pr create \
      --repo "$ORG/$repo" \
      --head "$BRANCH" \
      --base "$base" \
      --title "ci: ${COMMIT_SUBJECT:-enable organization Claude PR review}" \
      --body "${PR_INTRO:-Adds the caller workflow for the organization-wide Claude PR review.}

All configuration lives in [MagellanTV/.github](https://github.com/MagellanTV/.github):

- Prompt and run logic: \`.github/workflows/org-claude-review.yml\`
- Review policy: \`claude-guidelines/_org.md\`
- Platform checklist: \`claude-guidelines/<platform>.md\`
- Per-project profile: \`org-claude-config.yml\`

This repository's own \`CLAUDE.md\` is still read on top of those.

Opt out of a single PR with the \`skip-claude-review\` label."
  )
  echo "    PR opened"
done
