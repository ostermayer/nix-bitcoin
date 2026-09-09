# Audits

This branch is the **audit apparatus** for [nix-bitcoin](https://github.com/ostermayer/nix-bitcoin) — the methodology, the tooling, and every run's results. It lives on its own branch, deliberately **off** `master`/`release`, so the releases people pin stay clean of maintainer tooling. Nothing here is part of the node you deploy.

## Follow the audits

Every adversarial-LLM security review of the fork is published under [`runs/`](runs), one directory per run:

- `report.md` — summary + findings, sorted by severity
- `<model>.findings.json` / `findings.merged.json` — structured findings
- `<model>.raw.txt` — the **full model transcript** (nothing cherry-picked)
- `prompt.used.md` — the exact brief that produced this run

Findings are **advisory input to human review, never an automatic gate**: each is triaged into real / false-positive / accepted-risk, reals are fixed, and every fix re-runs the whole review. Three independent models run it — Kimi K3 and GLM 5.3 (Fireworks) at max reasoning, and GPT-6 Astra (OpenAI) at xhigh — so items flagged by more than one model are corroborated across three different labs' models.

## Have the suite

The two files here are all you need to run the same review yourself:

- [`prompt.md`](prompt.md) — the adversarial audit brief. **PRs to improve it are welcome** — if you can make the models find more real bugs or fewer false positives, open a PR (ideally with a before/after run).
- [`run.sh`](run.sh) — the runner: it checks out the fork read-only, runs each model inside a **bwrap sandbox** (the model's shell can't read the operator's SSH keys or secrets — see the header comments), extracts structured findings, scrubs output fail-closed for any secret, and publishes here.

It's wired for the maintainer's environment (needs the [`pi`](https://github.com/earendil-works/pi) agent, Fireworks and OpenAI API keys in `~/.config/fork-audit/secrets.env` (pi 0.84.x has no catalog entry for `gpt-6-astra` yet, so add one to `~/.pi/agent/models.json`), and `bwrap`), but the paths are env-overridable and the shape is easy to adapt:

```bash
./run.sh origin/release kimi-k3:max glm-5p3:max openai/gpt-6-astra:xhigh
# model = [provider/]id[:thinking]; bare ids are Fireworks models
```

## Secret safety

The runner carries no secrets. The model runs sandboxed with only the low-impact Fireworks key reachable; the SSH keys and secrets file are masked, and publishing **fails closed** if any secret or real PEM private-key block appears in the output. (This design came out of the audit auditing *itself* — see the run history.)

The security policy for reporting a vulnerability is in [`SECURITY.md`](https://github.com/ostermayer/nix-bitcoin/blob/master/SECURITY.md) on `master`.
