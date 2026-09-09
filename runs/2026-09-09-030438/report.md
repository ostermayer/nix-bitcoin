# Adversarial LLM audit — 2026-09-09-030438

- Commit audited: `d22c5daca12431b8fd697b5b61d818938f000e90` (ref `origin/audit-fixes-2026-09`)
- Models: gpt-6-astra (codex, thinking=xhigh)
- Prompt: the exact brief used is saved next to this report as `prompt.used.md`
- Findings: **0** total · 0 critical · 0 high · 0 flagged by >1 model

> ⚠ **RUN FAILED — NOT A CLEAN RESULT.** GPT-6 Astra (via the Codex CLI, ChatGPT login) was cut off by OpenAI's cyber-safety classifier about two minutes in, after reading a handful of modules: `ERROR: This content was flagged for possible cybersecurity risk … To get authorized for security work, join the Trusted Access for Cyber program`. No verdict was delivered; the "0 findings" below is an artifact. The harness treated a failed model as an empty result — fixed in the next `run.sh` (a model with no verdict now marks the run INCOMPLETE and exits nonzero). Re-run once the account is enrolled.

> LLM findings gate the release: the audit must complete and be reviewed before shipping.

No parseable findings — see the per-model transcripts.
