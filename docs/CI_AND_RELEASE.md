# GitHub Actions, verification and zero-cost policy

## Mandatory execution authority

Only GitHub Actions jobs can approve tests and produce the installer accepted for release. All 40 A01–A20 and B01–B20 require results in **Windows + genuine DaVinci Resolve Studio 20**, linked to the **same** commit, version, dataset manifest and Windows installer SHA-256. Standard runner tests support but do not replace host approval. Any missing, NOT RUN, BLOCKED, SKIPPED or FAIL case prevents a stable release.

Workflows target `ubuntu-latest`/`windows-latest` standard GitHub-hosted runners. An optional private Windows machine with a licensed Studio 20 installation may run a locked-down self-hosted runner if provided. Never run code from external PRs on that machine. Host workflow is restricted to protected/manual or reusable trusted release paths. Never use a paid runner, private paid build storage, third-party paid CI, Codespaces, or GitHub larger runners.

## Verified free-plan boundary

At preparation date (2026-11-10), GitHub documents standard GitHub-hosted runners as free in public repositories, with a **500 MB included Actions artifact storage allowance on GitHub Free shared with GitHub Packages**. Cache storage and logs have independent rules that may change. Verify limits, existing account usage and billing settings on every change; repository workflows cannot know all account-wide consumption. Do **not** enable overage billing or expand budgets. Configure a billing stop limit in repository/account settings; if verification is impossible, suspend artifact-heavy flows.

Sources:
- https://docs.github.com/en/actions/concepts/billing-and-usage
- https://docs.github.com/en/billing/reference/product-usage-included
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- https://docs.github.com/en/actions/reference/security/secure-use

## Workflow responsibilities

- `ci.yml`: source, specification SHA and traceability integrity, formatting/unit/static checks as real modules are built.
- `integration.yml`: actual integration test harness; no passing placeholder test. Incomplete source fails explicitly.
- `build-windows.yml`: real Windows installer + uninstaller from source, only in Actions; no uploaded local prebuilt installer.
- `package-validation.yml`: installer contents, SHA-256, manifest, GUI installer/uninstaller smoke checks on Windows.
- `fusion-host-tests.yml`: trusted real-host A/B tests with standardized, evidence-linked reports; never infer PASS.
- `release.yml`: single candidate run combining the above and releasing the **unchanged** approved installer only after all gates pass.

## Artifact retention / safety

1. Prefer no cache for this project until exact limits and dependencies are verified. Set `retention-days: 1` for temporary installers and `retention-days: 7` for compact host evidence only when required. Use built-in public Releases for approved long-lived installer files.
2. Enforce size checks before artifact upload. Never assume a 500 MB free quota is available if other repos/packages use it.
3. Pin third-party actions to reviewed full commit SHAs, use minimum `GITHUB_TOKEN` permissions, no write permissions on external PR jobs; never upload license files, Resolve binaries, credentials or personal projects.
4. A self-hosted runner should be ephemeral or strictly isolated, protected from untrusted PR workflows, and limited to trusted branches/environment approvals. A self-hosted runner cannot be regarded as an approved Fusion host without machine/license/version evidence.
5. Stable tags/releases require all required jobs PASS. Do not use `continue-on-error` for mandatory checks; do not treat missing checks as success.

## Current state

This file describes executable workflow policy and release design, not a passing implementation. In the foundation branch there are no Windows installer sources and no Fusion host evidence. Therefore **no installer or release is authorized**.

## Free branch protection

For public GitHub Free, branch protection or rulesets can require reviews/status checks. On `main`, require a PR, disable force-push/deletion and require the real `ci` and `integration` checks before merging; add protected host/release status checks at the corresponding milestone. This must be configured in Settings if the installed GitHub integration cannot mutate repository rulesets.
