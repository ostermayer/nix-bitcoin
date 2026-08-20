# Adversarial LLM security audits

This fork is red-teamed by open-weight LLMs acting as adversarial security
auditors, in addition to the deterministic guards (the NixOS VM assertion suite
in CI, and the [weekly vulnix CVE scan](../.github/workflows/cve-scan.yml)). The
models look for the class of defect scanners can't: *logic* bugs — privilege
boundaries, secrets leaking into the world-readable Nix store, RPC-whitelist
mistakes, systemd sandbox gaps, service-ordering that drops a security control.

**Everything here is public on purpose.** The exact prompt, the runner, and the
full model transcripts are all reviewable so you can judge the quality of the
review yourself — and propose improvements.

## What's here

| File | What |
|---|---|
| [`prompt.md`](prompt.md) | The adversarial audit brief given to every model. The single source of truth — the runner reads *this file from the audited commit*, so the published prompt is exactly the one that ran. |
| [`run.sh`](run.sh) | The runner. Checks out a throwaway, read-only, credential-free copy of the fork, runs each model with a read-only tool set, extracts structured findings, and publishes results. |

**Run history** — the report, per-model findings, and full transcripts for every
run — lives on the [`audits`](../../tree/audits/runs) branch (kept off the code
branches so it never affects CI or releases).

## Improving the prompt

The prompt is the most important part, and **pull requests to
[`prompt.md`](prompt.md) are welcome.** If you can make the models find more real
bugs — or fewer false positives — open a PR describing what class of issue your
change targets and, ideally, a before/after run. We evaluate prompt changes the
same way we evaluate any other: on whether they improve the precision and recall
of the review.

## How findings are used

LLM findings are **advisory input to human review — never an automatic gate.**
Each finding is triaged into *real / false-positive / accepted-risk*; reals are
fixed (via `pkgs/overrides.nix` or the relevant module) and the rest recorded.
Findings flagged independently by more than one model, and higher-severity ones,
are looked at first. Treat every finding as a lead to verify, not a verdict — a
hallucinated "critical" is worse than a missed "low", which is why the prompt
demands `file:line` evidence and an explicit attack scenario for every item.

## Secret safety

The runner contains no secrets (API keys are read at runtime from a file outside
the repo). The audit runs only against this **public** fork's code, read-only.
Before anything is published, every output file is scrubbed of the known secret
values, and **publishing fails closed** — it refuses to publish — if either (a)
any known secret value survives the scrub, or (b) *any* private-key material
appears at all (`PRIVATE KEY` / `BEGIN OPENSSH|RSA|EC|DSA|PGP`), known or not.
So even though the model has a shell and the runner's API keys and SSH keys are
reachable on the audit host, a model that dumps its environment or reads a key
file cannot leak it into the public history — the run just declines to publish.

## Reproducing a run

You need the [`pi`](https://github.com/earendil-works/pi) agent, a Fireworks API
key, and (optionally) Brave + Exa keys for web search. Point the keys at
`~/.config/fork-audit/secrets.env` and:

```bash
./audits/run.sh origin/release kimi-k3 glm-5p2
```
