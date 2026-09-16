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

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Collecting branches..."
: > "$work/all.txt"
for r in "${REPOS[@]}"; do
  gh api "repos/$ORG/$r/branches?per_page=100" --paginate \
    --jq ".[] | \"$r|\(.name)\"" 2>/dev/null >> "$work/all.txt" || true
done

echo "Collecting recent pull request head branches..."
: > "$work/recent.txt"
for r in "${REPOS[@]}"; do
  gh pr list --repo "$ORG/$r" --state all --limit 25 \
    --json headRefName --jq ".[] | \"$r|\(.headRefName)\"" 2>/dev/null >> "$work/recent.txt" || true
done

python3 - "$work/all.txt" "$work/recent.txt" <<'PY'
import collections, json, os, sys

here = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) if '__file__' in dir() else '.'
cfg = json.load(open(os.path.join(os.getcwd(), 'rulesets/org-branch-naming.json')))
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
