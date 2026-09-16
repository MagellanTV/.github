#!/usr/bin/env bash
# ============================================================================
# Create or update the organization-level rulesets from rulesets/*.json.
#
#   ./scripts/apply-org-rulesets.sh              # apply every file
#   ./scripts/apply-org-rulesets.sh org-pr-approvals.json
#   DRY_RUN=1 ./scripts/apply-org-rulesets.sh    # show what would happen
#
# Matching is by ruleset NAME: an existing ruleset with the same name is
# updated in place, so rerunning is safe and does not create duplicates.
#
# Both files ship with "enforcement": "evaluate". That records what each rule
# WOULD have blocked without blocking anything -- the only safe way to find out
# whether a rule breaks somebody's workflow. Read
# Organization settings -> Rulesets -> <ruleset> -> Insights for a few days,
# then flip "enforcement" to "active" and rerun this script.
#
# REQUIRES the admin:org scope. Without it the API returns 404, not 403:
#
#   gh auth refresh -h github.com -s admin:org
#
# admin:org grants full organization administration -- members, teams,
# webhooks, org secrets -- not just rulesets. If you would rather not hold it,
# create the two rulesets through the web UI instead; the JSON files mirror
# the fields the form asks for, one to one.
# ============================================================================
set -euo pipefail

ORG="MagellanTV"
DRY_RUN="${DRY_RUN:-0}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! gh api "orgs/$ORG/rulesets" >/dev/null 2>&1; then
  echo "Cannot read orgs/$ORG/rulesets." >&2
  echo "This needs the admin:org scope: gh auth refresh -h github.com -s admin:org" >&2
  exit 1
fi

existing="$(gh api "orgs/$ORG/rulesets" --jq '[.[] | {name, id}]')"

if [ $# -gt 0 ]; then
  files=()
  for f in "$@"; do files+=("$here/rulesets/$f"); done
else
  files=("$here"/rulesets/*.json)
fi

for file in "${files[@]}"; do
  name="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['name'])" "$file")"
  mode="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['enforcement'])" "$file")"
  id="$(echo "$existing" | python3 -c "
import json,sys
want = sys.argv[1]
print(next((r['id'] for r in json.load(sys.stdin) if r['name'] == want), ''))
" "$name")"

  if [ -n "$id" ]; then
    action="update (id $id)"
  else
    action="create"
  fi

  echo "==> $name [$mode] — $action"

  if [ "$DRY_RUN" = "1" ]; then
    echo "    dry run: no request sent"
    continue
  fi

  if [ -n "$id" ]; then
    gh api --method PUT "orgs/$ORG/rulesets/$id" --input "$file" \
      --jq '"    ok: \(.name) is \(.enforcement)"'
  else
    gh api --method POST "orgs/$ORG/rulesets" --input "$file" \
      --jq '"    ok: \(.name) is \(.enforcement), id \(.id)"'
  fi
done
