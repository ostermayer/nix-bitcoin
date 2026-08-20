#!/usr/bin/env bash
# run.sh — adversarial LLM security audit of this fork, with a PUBLIC history.
#
# Open-weight models (via the `pi` agent + Fireworks) red-team a throwaway,
# read-only checkout of this fork using the brief in ./prompt.md, and emit
# structured findings. Results — prompt used, per-model transcripts, findings,
# and a report — are published to the `audits` branch so anyone can review both
# what we asked and what the models answered.
#
# LLM findings are ADVISORY input to human review. They never gate a release on
# their own.
#
# Secret safety: this script contains NO secrets (keys come from
# ~/.config/fork-audit/secrets.env at runtime). Before publishing, every output
# file is scrubbed of the known secret VALUES and the publish FAILS CLOSED if
# any secret still appears — so a model that dumps its environment can never
# leak a key into the public branch.
#
# Usage: run.sh [ref] [model ...]        (default: origin/release, kimi-k3 glm-5p2)
# Env:   FORK_AUDIT_THINK=high  FORK_AUDIT_TIMEOUT=3600  FORK_AUDIT_NO_PUBLISH=1
#
# shellcheck disable=SC2016  # jq programs use single quotes intentionally
set -uo pipefail

WORK="${FORK_AUDIT_WORK:-$HOME/fork-audit}"
REPO_HTTPS="https://github.com/ostermayer/nix-bitcoin.git"
REPO_SSH="git@github.com:ostermayer/nix-bitcoin.git"
DEPLOY_KEY="${FORK_AUDIT_KEY:-$HOME/.ssh/id_ed25519_forkautotest}"
SIGN_KEY="${FORK_AUDIT_SIGN_KEY:-$HOME/.ssh/id_ed25519_forkautotest_sign}"
THINK="${FORK_AUDIT_THINK:-medium}"   # high wanders to ~40min/model; medium is the reliable default
TOOLS="read,bash,grep,git_status,git_diff,git_log,web_search,web_fetch"   # read-only
REF="${1:-origin/release}"; shift || true
MODELS=("$@"); [ ${#MODELS[@]} -gt 0 ] || MODELS=(kimi-k3 glm-5p2)

export PATH="$HOME/.npm-global/bin:/nix/var/nix/profiles/default/bin:$PATH"
set -a
# shellcheck disable=SC1091  # runtime secrets file, not present at lint time
. "$HOME/.config/fork-audit/secrets.env"
set +a
ALERT_TO="${ALERT_TO:-dan@ostermayer.co}"
ALERT_FROM="${ALERT_FROM:-NullR fork-audit <hi@lnzap.org>}"
have() { command -v "$1" >/dev/null; }
JQ() { jq "$@"; }   # native jq (present on pop-os and CI); nix-shell wrapping ate the args

STAMP="$(date +%F-%H%M%S)"
OUT="$WORK/reports/$STAMP"; SRC="$WORK/src"
mkdir -p "$OUT"
log() { printf '%s %s\n' "$(date -Is)" "$1"; }

# --- read-only, credential-free checkout -----------------------------------
log "checking out $REF"
rm -rf "$SRC"; git clone -q "$REPO_HTTPS" "$SRC" || { log "clone failed"; exit 1; }
git -C "$SRC" checkout -q "$REF" || { log "bad ref $REF"; exit 1; }
AUDITED_SHA="$(git -C "$SRC" rev-parse HEAD)"
git -C "$SRC" remote remove origin 2>/dev/null || true    # no push path for tools
PROMPT="$SRC/audits/prompt.md"
[ -f "$PROMPT" ] || { log "no audits/prompt.md at $REF"; exit 1; }
log "auditing $AUDITED_SHA · models: ${MODELS[*]} · thinking=$THINK"

TASK="You are auditing the nix-bitcoin fork checked out in the current directory ($SRC), at commit $AUDITED_SHA. Follow your security-audit brief exactly. Map the surface, investigate the highest-value targets, and end with the JSON findings array."

extract_json() { awk '/```json/{buf="";cap=1;next} cap&&/```/{last=buf;cap=0;next} cap{buf=buf $0 "\n"} END{printf "%s",last}' "$1"; }

for m in "${MODELS[@]}"; do
  mid="accounts/fireworks/models/$m"; raw="$OUT/$m.raw.txt"; fj="$OUT/$m.findings.json"
  log "=== $m ==="
  ( cd "$SRC" && timeout "${FORK_AUDIT_TIMEOUT:-3600}" \
      pi -p --provider fireworks --model "$mid:$THINK" --tools "$TOOLS" \
         --append-system-prompt "$PROMPT" "$TASK" ) > "$raw" 2> "$OUT/$m.stderr" \
    || log "$m exited nonzero (partial output kept)"
  extract_json "$raw" > "$fj"
  if have jq && jq -e . "$fj" >/dev/null 2>&1; then log "$m: $(jq 'length' "$fj") findings"; else log "$m: no parseable JSON"; echo '[]' > "$fj"; fi
done

# --- merge + report --------------------------------------------------------
MERGED="$OUT/findings.merged.json"; REPORT="$OUT/report.md"
: > "$OUT/.all.json"
for m in "${MODELS[@]}"; do JQ --arg model "$m" 'map(.+{model:$model})' "$OUT/$m.findings.json" >> "$OUT/.all.json" || true; done
JQ -s 'add // []' "$OUT/.all.json" > "$MERGED" || echo '[]' > "$MERGED"
total=$(JQ 'length' "$MERGED" || echo 0); crit=$(JQ '[.[]|select(.severity=="critical")]|length' "$MERGED" || echo 0)
high=$(JQ '[.[]|select(.severity=="high")]|length' "$MERGED" || echo 0)
corrob=$(JQ '[group_by(.file+"|"+(.title//""))[]|select(length>1)]|length' "$MERGED" || echo 0)
{
  echo "# Adversarial LLM audit — $STAMP"; echo
  echo "- Commit audited: \`$AUDITED_SHA\` (ref \`$REF\`)"
  echo "- Models: ${MODELS[*]} (Fireworks, thinking=$THINK)"
  echo "- Prompt: [\`audits/prompt.md\`](../../blob/$AUDITED_SHA/audits/prompt.md) at the audited commit"
  echo "- Findings: **$total** total · $crit critical · $high high · $corrob flagged by >1 model"; echo
  echo "> LLM findings are ADVISORY input to human review — not a release gate."; echo
  if have jq && [ "${total:-0}" != 0 ]; then
    jq -r --argjson o '{critical:0,high:1,medium:2,low:3,info:4}' 'sort_by($o[.severity]//9)|.[]|
      "## [\(.severity)] \(.title)\n- model: \(.model) · confidence: \(.confidence) · \(.category)\n- \(.file):\(.line)\n- attack: \(.attack_scenario)\n- fix: \(.recommendation)\n"' "$MERGED" 2>/dev/null \
    || jq -r '.[]|"- [\(.severity)] \(.title) (\(.model)) — \(.file):\(.line)"' "$MERGED"
  else echo "No parseable findings — see the per-model transcripts."; fi
} > "$REPORT"
log "report: $REPORT"

# --- SECRET SCRUB (fail-closed) --------------------------------------------
# The model has a bash tool and the API keys live in its environment, and a
# repo-write SSH deploy key + a signing key sit on disk (readable by this user).
# A curious model could `env` or `cat ~/.ssh/…` into its transcript. So: redact
# the known secret VALUES, and then FAIL CLOSED — refuse to publish — if (a) any
# known secret value survives, or (b) ANY private-key material appears at all,
# known or not. We never try to "clean" an unknown key; we just refuse.
PUBFILES=("$REPORT" "$MERGED"); for m in "${MODELS[@]}"; do PUBFILES+=("$OUT/$m.findings.json" "$OUT/$m.raw.txt"); done
secrets=("${FIREWORKS_API_KEY:-}" "${BRAVE_API_KEY:-}" "${EXA_API_KEY:-}" "${RESEND_API_KEY:-}")
# Include the private-key file contents so a leaked key body is redacted too.
for k in "$DEPLOY_KEY" "$SIGN_KEY"; do [ -f "$k" ] && secrets+=("$(cat "$k")"); done
for f in "${PUBFILES[@]}"; do [ -f "$f" ] || continue
  for s in "${secrets[@]}"; do [ -n "$s" ] || continue
    # Redact per-line so multi-line key bodies are handled; then the fail-closed
    # markers below are the real guarantee.
    esc=$(printf '%s' "$s" | head -1 | sed 's/[#&/\\]/\\&/g'); [ -n "$esc" ] && sed -i "s#${esc}#[REDACTED]#g" "$f"
  done
done
LEAK=0
for f in "${PUBFILES[@]}"; do [ -f "$f" ] || continue
  for s in "${secrets[@]}"; do [ -n "$s" ] || continue
    first=$(printf '%s' "$s" | head -1)
    if [ -n "$first" ] && grep -Fq "$first" "$f"; then log "SECRET VALUE present in $f — refusing to publish"; LEAK=1; fi
  done
  # (b) fail closed on ANY private-key material, whatever its source.
  if grep -qE 'PRIVATE KEY|BEGIN (OPENSSH|RSA|EC|DSA|PGP)' "$f"; then
    log "PRIVATE-KEY MATERIAL in $f — refusing to publish"; LEAK=1
  fi
done
if [ "$LEAK" = 0 ]; then log "secret scrub clean"; else log "secret scrub FAILED — publish blocked"; fi

# --- publish to the `audits` branch ----------------------------------------
publish() {
  [ "${FORK_AUDIT_NO_PUBLISH:-0}" = 1 ] && { log "publish skipped (FORK_AUDIT_NO_PUBLISH)"; return; }
  [ "$LEAK" = 0 ] || { log "publish ABORTED — secret scrub failed"; return; }
  local pub="$WORK/publish"
  export GIT_SSH_COMMAND="ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  if [ ! -d "$pub/.git" ]; then git clone -q "$REPO_SSH" "$pub" || { log "publish clone failed"; return; }; fi
  git -C "$pub" fetch -q origin || true
  if git -C "$pub" show-ref -q --verify refs/remotes/origin/audits; then
    git -C "$pub" checkout -q -B audits origin/audits
  else
    git -C "$pub" checkout -q --orphan audits; git -C "$pub" rm -rq --cached . 2>/dev/null || true
    find "$pub" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    printf '# Audit history\n\nGenerated adversarial-LLM audit runs. Methodology + prompt: the `audits/` dir on `master`.\n' > "$pub/README.md"
  fi
  git -C "$pub" config user.name "fork-autotest"; git -C "$pub" config user.email "ostermayer@users.noreply.github.com"
  if [ -f "$SIGN_KEY.pub" ]; then git -C "$pub" config gpg.format ssh; git -C "$pub" config user.signingkey "$SIGN_KEY.pub"; git -C "$pub" config commit.gpgsign true; fi
  local dst="$pub/runs/$STAMP"; mkdir -p "$dst"
  cp "$REPORT" "$MERGED" "$dst"/ 2>/dev/null
  cp "$SRC/audits/prompt.md" "$dst/prompt.used.md"
  for m in "${MODELS[@]}"; do cp "$OUT/$m.findings.json" "$OUT/$m.raw.txt" "$dst"/ 2>/dev/null; done
  git -C "$pub" add -A
  git -C "$pub" commit -q -m "audit $STAMP — ${AUDITED_SHA:0:12} — $total findings ($crit crit/$high high)" || { log "nothing to publish"; return; }
  if git -C "$pub" push -q origin audits; then log "published to audits branch: runs/$STAMP"; else log "publish push failed"; fi
}
publish

# --- email -----------------------------------------------------------------
if [ -n "${RESEND_API_KEY:-}" ] && have jq && [ "$LEAK" = 0 ]; then
  if curl -sS -m 30 https://api.resend.com/emails -H "Authorization: Bearer $RESEND_API_KEY" -H "Content-Type: application/json" \
       -d "$(jq -n --arg f "$ALERT_FROM" --arg t "$ALERT_TO" --arg s "[fork-audit] $total findings ($crit crit/$high high) @ ${AUDITED_SHA:0:8}" --arg b "$(cat "$REPORT")" '{from:$f,to:[$t],subject:$s,text:$b}')" >/dev/null
  then log "emailed $ALERT_TO"; else log "email failed"; fi
fi
log "done — $OUT"
