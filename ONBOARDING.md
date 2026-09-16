# Adding a repository to the MagellanTV org automation

What it takes to get Claude reviewing pull requests in a project, and what to
check when it does not work. Roughly ten minutes for a repository that already
has Actions enabled.

---

## Before you start

Three things are already set up at the organization level and are not per-repo:

- Organization secret **`CLAUDE_CODE_OAUTH_TOKEN`**, visible to the repository
- The **Claude GitHub App**, installed on the organization
- This repository, holding the workflow, the guidelines and the config

If a repository was created after those were configured, it inherits all three.

---

## 1. Check Actions is enabled

Some repositories have GitHub Actions switched off. Nothing below runs if it is.

```bash
gh api repos/MagellanTV/<repo>/actions/permissions --jq '.enabled'
```

`false` means go to **Settings → Actions → General → Allow all actions and
reusable workflows**, or:

```bash
gh api --method PUT repos/MagellanTV/<repo>/actions/permissions \
  -f enabled=true -f allowed_actions=all
```

---

## 2. Add the project to `org-claude-config.yml`

```yaml
projects:
  <repo-name>:
    platform: <profile>
    description: "One line, for whoever reads this file next"
```

**The key is the GitHub repository name, not the local folder name.** They
differ for some projects — the `magellantv_dev_ci` folder is the
`magellantv-backend` repository, `newui-web` is `magellantv-web`. The workflow
looks the project up by `github.event.repository.name`; a key that does not
match falls back to `defaults` silently, with no error and a generic review.

Pick a `platform` from `claude-guidelines/`:

| Profile | For |
|---|---|
| `smarttv` | Preact monorepo shipping to webOS, Tizen, Vizio, Vidaa, WhaleTV |
| `roku` | BrightScript and SceneGraph |
| `android` | Android, Fire TV, Kotlin |
| `apple` | iOS and tvOS |
| `web` | Browser front-ends |
| `backend` | Services, media pipeline, infrastructure |
| `tooling` | Scripts, CLIs, converters, remote configuration |
| `generic` | Fallback. If you land here, the project probably needs its own profile |

Override the model, effort or turn budget per project only when there is a
reason — see the header of `org-claude-config.yml`.

---

## 3. Add the caller workflow

Copy `claude-review.caller.yml` to `.github/workflows/claude-review.yml` in the
target repository, unchanged. The script does it and opens the PR:

```bash
DRY_RUN=1 ./scripts/rollout-claude-review.sh <repo>   # preview
./scripts/rollout-claude-review.sh <repo>             # opens a PR
```

It branches as `feature/claude-pr-review` because several repositories reject
any other prefix (see §6).

**Keep the caller identical to the template.** All the tuning lives in this
repository, and a caller that drifts from the template is a caller that will
confuse whoever debugs it next.

---

## 4. Merge it, then test on a real PR

The caller **cannot review its own pull request**. `claude-code-action` refuses
to run when the workflow file on a PR differs from the version on the default
branch:

> Workflow validation failed. The workflow file must exist and have identical
> content to the version on the repository's default branch.

That is deliberate — it stops a pull request from rewriting the review that
judges it. So: merge the caller first, then open any ordinary PR to see a review.

The guard checks *the workflow file GitHub is running* and nothing it calls
into. Changes to `org-claude-review.yml`, the guidelines or the config in this
repository are reviewed normally.

---

## 5. Release-train repositories need the caller on the release branch too

If the project merges features into an open release branch rather than the
default branch — `smart-tv` does, see its `CLAUDE.md` — then a PR targeting
that release branch produces a merge ref without the workflow, and nothing
runs. The team's actual pull requests go unreviewed while the default branch
looks correctly configured.

Carry the file over once:

```bash
git checkout -b fix/claude-review-on-release origin/release/<version>
git show <default-branch>:.github/workflows/claude-review.yml \
  > .github/workflows/claude-review.yml
```

Byte-identical to the default branch, or §4's guard rejects it. Release
branches cut after the caller lands pick it up on their own.

---

## 6. Branch naming

Several repositories run a **Branch Naming Convention** ruleset that only
permits `feature/`, `fix/`, `hotfix/` and `release/` prefixes. Anything else is
rejected at push time:

```
remote: error: GH013: Repository rule violations found
remote: - Cannot create ref due to creations being restricted.
```

This is a push-time failure, not a merge-time one — the branch never reaches
the remote.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| No `Claude PR Review` run at all | Actions disabled (§1); or the PR targets a release branch without the caller (§5); or the diff only touches `paths-ignore` entries |
| Run skipped with "Workflow validation failed" | The PR edits the caller itself (§4). Merge it, then test on a different PR |
| `startup_failure` in ~1 second | The reusable workflow requests a permission the caller does not grant. A called workflow cannot exceed its caller's permissions — update both |
| `is_error: true`, one turn, zero model usage | Authentication. Label the PR `claude-debug` and rerun to see the real error in the log; `401 Invalid bearer token` means the org secret needs regenerating with `claude setup-token` |
| Review is generic, ignores the platform | The `org-claude-config.yml` key does not match the repository name (§2) |
| Findings all in one comment, none inline | Check `classify_inline_comments`; it buffers inline comments and can suppress them |
| Review ran on a fork PR | It did not. Forks never receive organization secrets, so the job skips rather than failing red |

**Skip one pull request:** label it `skip-claude-review`.
**Debug one pull request:** label it `claude-debug` and rerun. Registered
secrets stay masked, but tool results are printed — use it on a diff you are
willing to see echoed into the run log.

---

## Unifying rulesets across the organization

Branch protection is currently per repository and inconsistent. Of the twelve
reachable repositories — `org-claude-config.yml` lists thirteen, but
`magellantv-app-config` currently returns 404 — **six** have
**Branch Naming Convention** and **two** have **PR Approvals**. Nothing
enforces the other six.

| Rulesets | Repositories |
|---|---|
| Branch Naming + PR Approvals | `smart-tv`, `magellantv-android` |
| Branch Naming only | `magellantv_roku`, `magellantv-ios`, `magellantv-backend`, `magellantv-web` |
| None | `apple-tv`, `magellantv-encoder`, `magellantv-aspera-sync`, `magellan_analytics_kmp`, `workticket`, `FM_.xlsx_to_JSON` |

**Organization rulesets are available on the Team plan** and fix this: define
the rule once, target repositories by pattern, and every repository inherits it.

Both are written out in `rulesets/`, derived from what `smart-tv` already runs:

| File | What it does |
|---|---|
| `rulesets/org-branch-naming.json` | Restrict creations on `~ALL` except `feature/*`, `fix/*`, `hotfix/*`, `release/*` and the default-branch names in use (`main`, `master`, `develop`, `legacy`, `legacy-develop`) |
| `rulesets/org-pr-approvals.json` | On `~DEFAULT_BRANCH`: restrict deletions, block force pushes, require a PR with 1 approval, code-owner review, last-push approval and thread resolution |

Two ways to apply them:

**Through the UI** — Organization settings → Repository → Rulesets → New
ruleset → New branch ruleset. The JSON mirrors the fields the form asks for,
one to one. No token changes needed; this is the recommended route.

**Through the API** — `./scripts/apply-org-rulesets.sh`, which creates or
updates by ruleset name so rerunning is safe. It needs `admin:org`
(`gh auth refresh -h github.com -s admin:org`), and that scope grants full
organization administration — members, teams, webhooks, org secrets — not just
rulesets. Worth weighing against five minutes in the UI.

**No repository is excluded.** Both rules apply to every repository in the org,
including this one.

**Who can bypass**, mirroring `smart-tv`:

| Ruleset | Bypass |
|---|---|
| Branch Naming Convention | Nobody |
| PR Approvals | Organization admins, and repository role 5 (admin) |

`actor_id` is `null` on the `OrganizationAdmin` entry on purpose — GitHub's
schema says it is ignored for that actor type, and this is the shape the API
returns for the live `smart-tv` ruleset.

Note the extra branch exclusions versus `smart-tv`'s copy: `master`, `legacy`
and `legacy-develop` are default branches elsewhere in the org, and `apple-tv`
also carries branches like `VRT-2067-danfelix` and `bug/VRT-1960` that the
naming rule would reject. That is what Evaluate mode is for.

Both files ship as **Evaluate**. It records what *would* have been blocked
without blocking anything, which is the only safe way to find out whether a
rule breaks someone's workflow. Move to **Active** once the evaluation is quiet.

Org rulesets are additive to repository rulesets — the strictest rule wins, and
neither replaces the other. Delete the per-repo copies only after the org rule
is Active and you have confirmed it covers the same ground.

**What is *not* available on Team:** the **Require workflows to pass before
merging** rule, which is Enterprise Cloud only. That rule is the one that would
let us run the review org-wide with no caller file in any repository. Until an
upgrade, the per-repo caller in §3 is the mechanism.

Creating org rulesets needs `admin:org`; a token with only `repo` and
`read:org` gets a 404 from the rulesets API.
