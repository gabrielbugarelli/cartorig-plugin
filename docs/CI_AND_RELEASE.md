# Build, verification and zero-cost policy

## Execution authority

CartoRig separates **development verification** from **installer packaging**.

- Source, Lua, Python, data-builder, integration, regression, installer-policy and repository-structure tests are executed in the development environment before a build candidate is pushed.
- GitHub Actions is used **only** to build/package the final Windows installer candidate from committed source and pinned Natural Earth data.
- GitHub Actions must not run product tests, integration tests, mock host tests or acceptance tests.
- Resolve Studio 20 acceptance is executed on a genuine licensed Windows host using the exact installer artifact and SHA-256 produced by the build-only workflow.
- No mock, local automated test or installer build can turn A01–A20/B01–B20 into PASS.

A missing, NOT RUN, BLOCKED, SKIPPED or FAIL host case remains unapproved.

## GitHub Actions boundary

The repository contains one manual workflow:

`.github/workflows/scene-timeline-windows.yml`

It can be triggered by `workflow_dispatch`. On the active Milestone A
development branch, a commit that changes **only the installer workflow file**
may also trigger packaging; ordinary implementation commits do not run Actions.
Both paths execute the same build-only job:

1. check out the committed CartoRig source;
2. fetch the exact pinned Natural Earth commit;
3. generate offline runtime data with the pinned free build dependency;
4. compile the NSIS Windows installer;
5. record installer SHA-256, source commit and Natural Earth commit;
6. upload the installer artifact for a short retention period.

It does **not** execute Python/Lua/unit/integration/acceptance tests. Functional correctness must already have been reviewed and tested before dispatch.

Only free/public GitHub resources are permitted: standard public-repository runners, built-in artifact storage within free limits, and pinned free/open-source build tools. Paid/larger runners, Codespaces, paid CI/SaaS, paid storage expansion and overage billing are prohibited.

## Local pre-build gate

Before dispatching the installer build, the developer must execute and review locally:

- Python unit/static/policy tests;
- Lua source/module regressions;
- Blackmagic API contract regressions;
- Scene/timeline transaction mocks clearly marked non-host;
- Natural Earth generator tests using local fixtures;
- generated-runtime checks when the exact pinned dataset is locally available;
- specification SHA / traceability structure verification.

Every failure is corrected before the build request. Tests and implementation are reviewed together after each increment.

## Safe upgrade of CartoRig-owned shared files

The installer must accept an unmodified previous CartoRig installation and
must not overwrite independently authored files in Resolve's shared folders.
Before building an updated `.fuse` or launcher, refresh the normalized SHA-256
allowlist in `support/verify-managed-shared.ps1` using exact bytes from the
reviewed previous installer and the newly committed source. Keep historical
CartoRig hashes to support upgrades and uninstall, and do not replace the
allowlist with filename-only or wildcard checks.

The local `tests/test_installer_safety.py` verifies that all source files
distributed by the current installer are recognized by the ownership verifier.
An installer build is not proof of an upgrade unless this local test passes
and an actual old-to-new installation has been checked on Windows.

## Host gate

The stable release requires all normative host cases with evidence tied to:

- CartoRig commit;
- installer SHA-256;
- CartoRig version;
- Resolve Studio version;
- Natural Earth manifest/source commit;
- observed result and evidence.

Host tests are never run on a generic GitHub-hosted runner and are never inferred from build success.

## Artifact and security policy

- Keep the build workflow manual and read-only except for artifact upload.
- Pin third-party Actions to reviewed full commit SHAs.
- Use minimum `GITHUB_TOKEN` permissions.
- Do not cache proprietary files or upload Resolve binaries, credentials, personal projects or licensed SDK material.
- Keep installer artifacts short-lived while the product is under development.
- Stable Releases, when eventually authorized, publish the unchanged host-approved installer.

## Current state

0.7.0 is a Milestone A development candidate. Local automated verification can establish source/data/transaction consistency, but Resolve Studio Viewer, Inspector, render and save/reopen evidence remains mandatory before Milestone A can be accepted.
