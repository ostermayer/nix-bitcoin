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
the repo). The audit runs only against this **public** fork's code. Defense is
layered, primary control first:

1. **Sandbox (primary).** The model's `pi` process runs inside a `bwrap`
   sandbox: the whole filesystem is read-only, and the operator's SSH deploy and
   signing keys (`~/.ssh`) and the secrets file are **masked with empty tmpfs**,
   so the model's shell literally cannot read them. The pi config is exposed
   through a throwaway overlay (reads work; writes can't touch the real config).
   Only the low-impact Fireworks API key is reachable in the model's env.
2. **No network tools.** `web_search`/`web_fetch` are disabled, removing the
   prompt-injection-via-fetched-page vector.
3. **Separate publish.** The push (which needs the deploy key) runs *after* the
   model exits, as a step no model participates in.
4. **Fail-closed scrub (last line).** Before publishing, output is scrubbed of
   known secret values, and the run **refuses to publish** if any known value
   survives or a real PEM private-key block (`-----BEGIN … PRIVATE KEY-----`)
   appears.

This design came out of the audit auditing *itself*: an earlier version exposed
the keys to the model and relied on the scrub alone; the models flagged that a
shell + network + on-disk deploy key is exfiltration-capable regardless of a
publish-time scrub, so the keys were moved out of the model's reach entirely.

## Reproducing a run

You need the [`pi`](https://github.com/earendil-works/pi) agent, a Fireworks API
key, and (optionally) Brave + Exa keys for web search. Point the keys at
`~/.config/fork-audit/secrets.env` and:

```bash
./audits/run.sh origin/release kimi-k3 glm-5p2
```
