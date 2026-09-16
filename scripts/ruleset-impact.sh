#!/usr/bin/env bash
# ============================================================================
# What a branch-naming ruleset would block, measured against real branches.
#
#   ./scripts/ruleset-impact.sh
#
# Evaluate mode -- the GitHub feature that answers this question by recording
# what a rule WOULD have blocked -- is Enterprise Cloud only. The API accepts
# "enforcement": "evaluate" on a Team plan and stores it, but the ruleset then
# applies to nothing: it neither enforces nor records. This script is the
# stand-in. Run it before flipping a naming rule to active.
#
# It reports two numbers, and the gap between them is the point:
#
#   every branch     includes years of abandoned branches, so it overstates
#   recent PR heads  what people actually do now, which is what will break
# ============================================================================
set -euo pipefail

ORG="MagellanTV"
REPOS=(apple-tv FM_.xlsx_to_JSON magellan_analytics_kmp magellantv-backend
       magellantv_roku magellantv-android magellantv-aspera-sync
       magellantv-encoder magellantv-ios magellantv-web smart-tv workticket)

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Every failure is reported. A repository that silently contributes zero rows
# does not read as an error -- it reads as a repository with tidy branch names,
# which is the one way this script can talk somebody into the wrong decision.
failures=0

collect() {
  local label="$1" out="$2"; shift 2
  echo "Collecting $label..."
  : > "$out"
  for r in "${REPOS[@]}"; do
    local before after err
    before="$(wc -l < "$out")"
    err="$work/err.txt"
    if [ "$label" = "branches" ]; then
      gh api "repos/$ORG/$r/branches?per_page=100" --paginate \
        --jq ".[] | \"$r|\(.name)\"" >> "$out" 2>"$err" || true
    else
      gh pr list --repo "$ORG/$r" --state all --limit 25 \
        --json headRefName --jq ".[] | \"$r|\(.headRefName)\"" >> "$out" 2>"$err" || true
    fi
    after="$(wc -l < "$out")"
    if [ -s "$err" ]; then
      echo "  !! $r: $(head -1 "$err")" >&2
      failures=$((failures + 1))
    elif [ "$before" -eq "$after" ]; then
      echo "  !! $r: returned nothing — verify this is real before trusting the totals" >&2
      failures=$((failures + 1))
    fi
  done
}

collect branches "$work/all.txt"
collect "recent pull request head branches" "$work/recent.txt"

if [ "$failures" -gt 0 ]; then
  echo
  echo "WARNING: $failures repository/collection pair(s) produced no data or errored." >&2
  echo "The percentages below are computed over what was actually collected." >&2
fi

python3 - "$work/all.txt" "$work/recent.txt" "$here" <<'PY'
import collections, json, os, sys

# Repo root comes from the shell, which derived it from BASH_SOURCE. Reading it
# relative to the working directory only works when the script is run from the
# repo root, and this is a script people will run from wherever they are.
repo_root = sys.argv[3]
cfg = json.load(open(os.path.join(repo_root, 'rulesets/org-branch-naming.json')))
excludes = cfg['conditions']['ref_name']['exclude']

prefixes = tuple(e[len('refs/heads/'):-1] for e in excludes if e.endswith('/*'))
exact = {e[len('refs/heads/'):] for e in excludes if not e.endswith('/*')}

def blocked(name):
    return not (name.startswith(prefixes) or name in exact)

def report(path, label):
    rows = [l.strip().split('|', 1) for l in open(path) if '|' in l]
    bad = [(r, n) for r, n in rows if blocked(n)]
    pct = 100 * len(bad) / len(rows) if rows else 0
    print(f"\n{label}: {len(bad)} of {len(rows)} blocked ({pct:.0f}%)")
    per = collections.defaultdict(list)
    for r, n in bad:
        per[r].append(n)
    for r in sorted(per, key=lambda x: -len(per[x])):
        print(f"  {r:<24} {len(per[r]):>4}   {', '.join(per[r][:3])}")
    return bad

print(f"\nAllowed prefixes: {', '.join(prefixes)}")
print(f"Allowed exact:    {', '.join(sorted(exact))}")

report(sys.argv[1], "Every branch that exists")
bad = report(sys.argv[2], "Recent pull request head branches")

print("\nMost common blocked prefixes, all branches:")
pref = collections.Counter()
for l in open(sys.argv[1]):
    if '|' not in l:
        continue
    n = l.strip().split('|', 1)[1]
    if blocked(n):
        pref[n.split('/')[0] + '/' if '/' in n else '<none>'] += 1
for p, c in pref.most_common(10):
    print(f"  {p:<16} {c}")
PY
