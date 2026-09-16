# .github — MagellanTV organization automation

Shared GitHub configuration for every MagellanTV repository. Workflow logic and
policy live here; consumer repositories carry only a thin caller.

## What lives here

| Path | Purpose |
|------|---------|
| `PULL_REQUEST_TEMPLATE.md` | Organization pull request template |
| `.github/workflows/org-required-reviews.yml` | Reusable: required reviewers per team |
| `.github/workflows/org-claude-review.yml` | Reusable: Claude PR review |
| `.github/workflows/org-claude-review-ruleset.yml` | Ruleset entrypoint for the Claude review (GHEC) |
| `org-team-mapping.yml` | Which teams must review which project |
| `org-labeler.yml` | Shared auto-labeling rules |
| `org-claude-config.yml` | Per-project Claude review profile |
| `claude-guidelines/` | Review policy and platform checklists |
| `claude-review.caller.yml` | Template to copy into a consumer repository |
| `scripts/rollout-claude-review.sh` | Opens the caller PR across repositories |
| `ONBOARDING.md` | How to enable the review on a new repository, and troubleshooting |

---

## Claude PR review

Claude reviews pull requests using three layers, in order:

1. **`claude-guidelines/_org.md`** — organization policy. Severity scale, output
   format, and the list of things not worth commenting on. Change this file to
   change how every project is reviewed.
2. **`claude-guidelines/<platform>.md`** — platform checklist, selected by the
   `platform` key in `org-claude-config.yml`.
3. **The repository's own `CLAUDE.md`** — architecture, commands and local
   conventions. It wins over the two files above.

### Enabling it in a repository

Full walkthrough, including the release-train and branch-naming gotchas, in
**[ONBOARDING.md](ONBOARDING.md)**. The short version — copy
`claude-review.caller.yml` to `.github/workflows/claude-review.yml`, or let the
script do it:

```bash
DRY_RUN=1 ./scripts/rollout-claude-review.sh smart-tv   # preview
./scripts/rollout-claude-review.sh smart-tv             # opens a PR
```

The script branches as `feature/claude-pr-review`, because several repositories
run a Branch Naming Convention ruleset that only allows `feature/`, `fix/`,
`hotfix/` and `release/` prefixes.

### The caller must be on the default branch first

`claude-code-action` refuses to run when the workflow file on the pull request
differs from the version on the repository's default branch:

> Workflow validation failed. The workflow file must exist and have identical
> content to the version on the repository's default branch.

That is a deliberate guard against a pull request rewriting the review that
judges it. Two consequences:

- **The PR that adds `claude-review.yml` cannot review itself.** Merge it, then
  open any ordinary pull request to see the review run.
- **Changes to `claude-review.yml` skip the review** until they land on the
  default branch.

The guard checks *the workflow file GitHub is running* — the caller, or
`org-claude-review-ruleset.yml` in this repository — and nothing else. A PR
that edits `org-claude-review.yml`, the guidelines or the config is still
reviewed, because the reusable workflow is checked out at `main` on every run
and is not what GitHub validates. A PR that edits the entrypoint is skipped.

Keep the caller identical to `claude-review.caller.yml` and do the tuning here.

### Enabling it org-wide without touching repositories

**Not available today.** The rule below is GitHub Enterprise Cloud only and the
organization is on the **Team** plan, so `org-claude-review-ruleset.yml` is
inert. The per-repo caller is what runs the review. Kept documented in case the
org upgrades.

On Enterprise Cloud, an organization ruleset can run the workflow across
repositories with no file in any of them:

> Organization settings → Rulesets → New ruleset → Target: repositories
> Rule: **Require workflows to pass before merging**
> Source repository `MagellanTV/.github`, path
> `.github/workflows/org-claude-review-ruleset.yml`, ref `main`

Start the ruleset in **Evaluate** mode to confirm the run and the organization
secret resolve before switching it to **Active**.

Both paths run the same reusable workflow, so the review behaves identically.

### Prerequisites

- Organization secret **`CLAUDE_CODE_OAUTH_TOKEN`**, visible to the repositories
  in scope. Generate it with `claude setup-token`.
- The **Claude GitHub App** installed on the organization
  (<https://github.com/apps/claude>), so review comments come from `claude[bot]`
  and inline comments work.
- Actions must be allowed to run `anthropics/claude-code-action` — check
  Organization settings → Actions → Policies if third-party actions are
  restricted.

### Tuning

| Knob | Where |
|------|-------|
| Review policy, severity, output format | `claude-guidelines/_org.md` |
| Platform checklist | `claude-guidelines/<platform>.md` |
| Platform per project | `org-claude-config.yml` |
| Model, effort, turn budget | `org-claude-config.yml` (`defaults`, or per project) |
| Which events trigger a review | `on:` block in the caller |
| Paths that never trigger a review | `paths-ignore` in the caller |

Skip a single pull request with the **`skip-claude-review`** label. Label one
**`claude-debug`** to get the full SDK transcript in the run log.

Findings land as **inline comments on the offending line**; the single top-level
comment is a verdict plus an index pointing at them. `track_progress` is off on
purpose — it hands the summary comment to the action, which prepends a header
no input can remove.

Reviews run on `opened`, `ready_for_review` and `reopened` — deliberately not on
every push, so a PR is reviewed once rather than once per commit.

Pull requests from forks are skipped: GitHub does not expose organization
secrets to them.

---

## Required reviews

`org-required-reviews.yml` reads `org-team-mapping.yml`, requires an approval
from each mapped team, assigns the PR to its author, and requests a reviewer
from each team. Consumer repositories call it from
`.github/workflows/required-reviews.yml` and pass `REQUIRED_REVIEWS_TOKEN`.

## Labeling

`org-labeler.yml` holds the shared label rules. Consumer repositories check this
repository out and point `actions/labeler` at it, so label rules change in one
place.
