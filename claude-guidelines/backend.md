# Platform checklist — Backend / services / tooling

## Correctness and failure

- Every external call (HTTP, S3, database, encoder API) needs a timeout, a
  retry policy where retries are safe, and a defined behavior on failure.
- Retries on non-idempotent operations duplicate work. Flag them.
- Partial failure in a batch: say what happens to the items that already
  succeeded.

## Media pipeline

- Changes to encoding profiles, bitrate ladders, codec settings or manifest
  generation affect every device in the field, including TV apps that cannot
  be updated quickly. Treat these as high risk and say so explicitly.
- Job state machines need a terminal state for every failure branch, or jobs
  hang forever.
- Storage paths and naming conventions are contracts with downstream
  consumers. Renaming one is a breaking change.

## Security and configuration

- Credentials, signing keys and connection strings in the diff are a Blocker.
- New IAM permissions, bucket policies or security group rules: check they are
  scoped, not wildcards.
- Configuration that differs between dev and prod must come from environment,
  not from a branch on a hostname.

## Operations

- New failure paths need a log line with enough context to debug, and no PII.
- Long-running or scheduled work needs a way to tell it ran and succeeded.
- Database migrations: confirm they are reversible, or say clearly that they
  are not.
