# Platform checklist — tooling, scripts and configuration

Repositories that nobody ships to a device: converters, CLIs, sync jobs,
deploy scripts, remote configuration. They break quietly and at the worst
moment, so the bar is different from product code — less about UX, more about
what happens when the input is wrong and nobody is watching.

## Failure behavior

- A script that processes records needs a defined answer for a bad record:
  skip and report, or stop. Silently dropping rows is the worst option and the
  most common one.
- Exit codes matter. A script that fails and exits `0` will be reported as a
  successful run by whatever schedules it.
- Partial completion: if it writes half its output and dies, say what the
  next run does with that state. Re-running should be safe.

## Input is untrusted

- Spreadsheets, CSVs and JSON from outside the repo will eventually arrive
  malformed, empty, or with an extra column. Parsing without validation is a
  defect, not a style preference.
- Encoding, locale and date parsing are where these scripts actually break.
  Flag naive `Date` parsing and locale-dependent number formatting.
- Paths built from input data need sanitizing before they reach the filesystem.

## Configuration and secrets

- Credentials, tokens, keys and connection strings in the diff are a **Blocker**.
  This includes `.pem` files and anything in a committed `.env` or `.ini`.
- Config that differs between environments comes from the environment, not from
  a branch on a hostname or a commented-out block.
- Remote configuration that clients read is a **contract**: a renamed or
  removed key breaks apps already installed. Treat shape changes as breaking.

## Operations

- New failure paths need a log line with enough context to debug, and no PII.
- Scheduled work needs a way to tell it ran and succeeded. "It didn't error"
  is not the same as "it worked".
- Long-running jobs: say what happens if two copies run at once.

## Proportionality

These repos are usually small and read by few people. Do not ask for
abstraction, dependency injection, or test infrastructure that the repository
has no precedent for. A 200-line script does not need a framework.
