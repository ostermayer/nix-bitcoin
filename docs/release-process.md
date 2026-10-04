# Weekly release process

This runbook is the authoritative process for maintainers publishing the
maintained fork's weekly release. The goal is to advance `release` to one exact,
reviewed commit with reproducible evidence: reviewed dependency changes, two
independent adversarial reviews, the full automated test suite, and fleet
validation.

The process is deliberately fail-closed. A missed week is safer than an
incomplete release. Security fixes do not wait for the weekly cadence; use the
same gates in an expedited release.

## Release invariants

- `master` is the integration branch. `release` only advances to a commit that
  is already on `master` and has passed every gate below.
- Promote with a fast-forward. Never force-push `release`, move an existing tag,
  or reuse a CalVer tag.
- The commit reviewed by Kimi K3 and GLM-5.3 must be the commit promoted. Any
  code, package, module, test, workflow, or security-relevant documentation
  change after review invalidates the review and requires a complete rerun.
- Both primary auditors must return a parseable verdict at maximum reasoning.
  A timeout, provider error, refusal, empty result, or parser warning is a failed
  gate—not a clean review.
- Model findings are advisory evidence. A maintainer must reproduce and triage
  every finding. Critical and high findings block release. Lower-severity
  findings must be fixed or recorded as an accepted risk with a concrete
  rationale and follow-up.
- All commits are signed. CI-created CalVer tags are annotated but unsigned;
  authenticate the commit, not the tag.
- Release evidence is public: audit transcripts live on the `audits` branch and
  GitHub Actions records the test results.

## 1. Prepare the candidate

Start from a clean, current `master`. Reconcile any divergence before changing
the pin so `origin/release` remains an ancestor of the candidate.

```bash
git fetch --prune origin
git switch master
git pull --ff-only origin master
git status --short
git merge-base --is-ancestor origin/release HEAD
```

The final command must succeed. If it does not, merge `origin/release` into
`master`, review the merge carefully, and restart this process from the merged
commit. Do not repair divergence by rewriting published history.

The weekly candidate is created by the `fork-autotest` timer on the build box
(Mondays, 03:30 local time). One run updates the flake inputs, refuses an lnd
downgrade, runs the local VM suite, evaluates the three fleet closures, and
pushes the signed branch `auto/pins-<date>`. It then sends the e-mail
"CANDIDATE READY". Review that branch. Create a candidate by hand only when
the timer did not run or failed:

```bash
date=YYYY-MM-DD
git switch -c "auto/pins-$date"
nix develop
update-flake.sh
```

`update-flake.sh` updates the flake inputs and regenerates `pkgs/pinned.nix`.
In both cases, review the lock-file revisions and the package movements:

```bash
git diff -- flake.nix flake.lock pkgs/pinned.nix
nix flake metadata
```

Do not accept a pin as a mechanical update. For every shipped service and
security-sensitive runtime dependency that changed:

1. Read the upstream release notes and security advisories.
2. Identify behavior changes, migrations, new listeners, permissions, secret
   handling, and changed defaults.
3. Check open CVE-scan findings and run the closure scan when the weekly job has
   not covered the candidate's dependency set.
4. Add a version-guarded fix in `pkgs/overrides.nix` when stable nixpkgs lags a
   required security release. The override must become inert automatically once
   the pin catches up.
5. Regenerate fixed-output dependency files when a package update requires it;
   never copy hashes from an untrusted build log without checking the source.

Keep the candidate focused. Unrelated feature work gets its own change and its
own review cycle.

## 2. Test locally

Run the static checks and every release-gating VM scenario:

```bash
nix flake check --all-systems
./test/shellcheck.sh
./test/run-tests.sh -s default build
./test/run-tests.sh -s regtest build
./test/run-tests.sh -s netns build
nix build --no-link .#tests.wireguard-lndconnect
```

The WireGuard scenario is a two-node test and is exposed directly as a flake
test rather than through `run-tests.sh`. A test restored from the binary cache
is valid only when its derivation exactly matches the candidate.

Also evaluate every production fleet configuration. Build or deploy to staging
when an update changes state formats, database versions, credentials, network
exposure, firewall behavior, or startup ordering. Record the evaluated fleet
revisions and any manual checks in the candidate commit message or release
tracking issue.

## 3. Commit and run the two-model red team

Commit the complete candidate with the signing key and verify the signature:

```bash
git add -A
git commit -S
git log -1 --show-signature
candidate=$(git rev-parse HEAD)
```

Run the audit harness from a separate checkout of the `audits` branch. The
harness invokes both open-weight models through `pi`, in a read-only sandbox,
at maximum reasoning and publishes the prompt, raw transcripts, and structured
findings:

```bash
./run.sh "$candidate" kimi-k3:max glm-5p3:max codex/gpt-6-astra:xhigh
```

Do not substitute one model for the other. The third model (GPT-6 Astra) is
a second opinion: it helps triage, but it does not replace either primary
review. The harness publishes its result as a separate "second opinion"
commit on the `audits` branch.

Read both raw transcripts as well as `report.md`; the merged count alone is not
enough. For each finding, record one of:

- **confirmed—fixed**, with the fixing commit and regression test;
- **false positive**, with evidence from the cited code or runtime behavior;
- **accepted risk**, with severity, exposure, compensating controls, owner, and
  intended revisit date.

After any release-relevant change, repeat the local tests and the complete K3 +
GLM-5.3 review against the new commit. The last published audit must name the
exact `candidate` SHA that will be promoted.

## 4. Validate in GitHub CI

Push the candidate branch and wait for every required check:

```bash
git push -u origin "HEAD:auto/pins-$date"
```

Required checks are:

- flake evaluation and shellcheck;
- VM scenarios `default`, `regtest`, and `netns`;
- the two-node `wireguard-lndconnect` scenario.

Inspect logs even when a job is green if it retried, used a fallback, or emitted
warnings about omitted tests. A cancelled, skipped, or missing required context
is not a pass.

Before promotion, verify all of the following against the candidate SHA:

```bash
test "$(git rev-parse HEAD)" = "$candidate"
git diff --exit-code
git log -1 --show-signature "$candidate"
git merge-base --is-ancestor origin/release "$candidate"
```

## 5. Promote and verify

Merge the reviewed candidate into `master` without changing its tree. If the
repository policy uses a pull request, require the exact candidate's checks and
do not add a post-review fix during merge. Then fetch and verify the resulting
`master` tree is identical to the audited tree:

```bash
git fetch origin master release
git diff --exit-code "$candidate^{tree}" "origin/master^{tree}"
git merge-base --is-ancestor origin/release origin/master
```

Promote by fast-forwarding `release` to `origin/master`:

```bash
git push origin origin/master:release
```

Branch protection must reject the push unless all required checks passed. The
`release-tag.yml` workflow then creates a unique `YYYY.MM.DD[.N]` tag and GitHub
release when closure-affecting files changed. Documentation-only releases do
not receive a tag.

Verify the public result:

1. `origin/release` resolves to the expected commit.
2. The commit signature is valid.
3. The release-tag workflow succeeded, or explicitly reported that no
   closure-affecting files changed.
4. A newly created tag resolves to that same commit.
5. The audit report on `audits` names that commit.
6. The release branch's required CI checks are green.

## 6. Roll out and monitor

Rehearse every release on the throwaway staging node before the fleet. Run
`staging-rehearsal.sh rehearse <tag>` from the fleet repository
(`configs/staging/`); it provisions the node, deploys the tag, and reports
service health. Do not skip the rehearsal for an lnd update or for an update
that changes a database version or a state format.

Then update the fleet in order: the watchtowers first, the production node
last. After each update confirm service health, logs, sync progress, peer
connectivity, Lightning channel state, Electrum queries, BTCPay checkout
behavior, backups, and nodeinfo output. Confirm that the lnd REST onion
address and the macaroons are unchanged: wallets connected over lndconnect
(Zeus) must keep working. Roll the same locked revision through the fleet.

For a regression, stop the rollout and fix forward through this process. An
individual deployment may temporarily restore its previous `flake.lock`, but
the public `release` branch and existing tags must not be rewritten.

## Release record

The candidate commit message or tracking issue should make the decision
auditable by recording:

- old and new nixpkgs revisions;
- shipped package version changes and upstream advisory links;
- any override added or removed;
- local test results and fleet configurations evaluated;
- audit run identifier, audited SHA, and disposition of every finding;
- GitHub Actions run and resulting CalVer tag;
- canary result and any follow-up work.
