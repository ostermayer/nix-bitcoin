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
# Usage: run.sh [ref] [model ...]        (default: origin/release, kimi-k3 glm-5p3)
#   model = [provider/]id[:thinking]. Bare ids are Fireworks models
#   (accounts/fireworks/models/<id>). `codex/gpt-6-astra:xhigh` runs GPT-6
#   Astra through the locally installed Codex CLI (`codex exec`, ChatGPT login
#   in ~/.codex/auth.json, its own read-only sandbox inside our bwrap).
#   `openai/gpt-6-astra:xhigh` is the API-key route via pi instead
#   (OPENAI_API_KEY in secrets.env). A missing :thinking falls back to
#   FORK_AUDIT_THINK.
#   Gate config since 2026-09-09: kimi-k3:max glm-5p3:max codex/gpt-6-astra:xhigh
# Env:   FORK_AUDIT_THINK=high  FORK_AUDIT_TIMEOUT=3600  FORK_AUDIT_NO_PUBLISH=1
#
# shellcheck disable=SC2016  # jq programs use single quotes intentionally
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # this suite lives on the `audits` branch
WORK="${FORK_AUDIT_WORK:-$HOME/fork-audit}"
REPO_HTTPS="https://github.com/ostermayer/nix-bitcoin.git"
REPO_SSH="git@github.com:ostermayer/nix-bitcoin.git"
DEPLOY_KEY="${FORK_AUDIT_KEY:-$HOME/.ssh/id_ed25519_forkautotest}"
SIGN_KEY="${FORK_AUDIT_SIGN_KEY:-$HOME/.ssh/id_ed25519_forkautotest_sign}"
THINK="${FORK_AUDIT_THINK:-medium}"   # high wanders to ~40min/model; medium is the reliable default
# Read-only tools ONLY. Deliberately NO web_search/web_fetch: a fetched page
# could prompt-inject the model, and network tools widen the exfil surface.
TOOLS="read,bash,grep,git_status,git_diff,git_log"
REF="${1:-origin/release}"; shift || true
SPECS=("$@"); [ ${#SPECS[@]} -gt 0 ] || SPECS=(kimi-k3 glm-5p3)
# Resolve each spec into parallel arrays: short name (file tag), provider,
# full model id, thinking level.
MODELS=(); PROVS=(); MIDS=(); THINKS=()
for spec in "${SPECS[@]}"; do
  t="$THINK"; case "$spec" in *:*) t="${spec##*:}"; spec="${spec%:*}";; esac
  case "$spec" in
    */*) prov="${spec%%/*}"; id="${spec#*/}";;
    *)   prov=fireworks; id="accounts/fireworks/models/$spec";;
  esac
  MODELS+=("${id##*/}"); PROVS+=("$prov"); MIDS+=("$id"); THINKS+=("$t")
done
describe_models() { local i; for i in "${!MODELS[@]}"; do printf '%s%s (%s, thinking=%s)' "$([ "$i" -gt 0 ] && echo ', ')" "${MODELS[$i]}" "${PROVS[$i]}" "${THINKS[$i]}"; done; }

export PATH="$HOME/.npm-global/bin:/nix/var/nix/profiles/default/bin:$PATH"
# Load secrets as NON-exported shell vars, then export ONLY the low-impact
# Fireworks key into the environment the sandboxed model inherits. The
# high-impact secrets never enter the model's world: RESEND is used only in the
# publish/email step below (run as this user, no model running), and the SSH
# deploy/sign keys are masked from the model by the bwrap sandbox around pi.
# shellcheck disable=SC1091  # runtime secrets file, not present at lint time
. "$HOME/.config/fork-audit/secrets.env"
export FIREWORKS_API_KEY
# Same class of secret as the Fireworks key: a spend-capped inference key with
# no access to funds or infrastructure. Only exported when set.
[ -n "${OPENAI_API_KEY:-}" ] && export OPENAI_API_KEY
ALERT_TO="${ALERT_TO:-dan@ostermayer.co}"
ALERT_FROM="${ALERT_FROM:-nix-bitcoin fork audit <hi@lnzap.org>}"
have() { command -v "$1" >/dev/null; }
JQ() { jq "$@"; }   # native jq (present on pop-os and CI); nix-shell wrapping ate the args

STAMP="$(date +%F-%H%M%S)"
OUT="$WORK/reports/$STAMP"; SRC="$WORK/src-$STAMP"   # per-run checkout: concurrent runs must not wipe each other
trap 'rm -rf "$SRC"' EXIT
mkdir -p "$OUT"
log() { printf '%s %s\n' "$(date -Is)" "$1"; }

# --- read-only, credential-free checkout -----------------------------------
log "checking out $REF"
rm -rf "$SRC"; git clone -q "$REPO_HTTPS" "$SRC" || { log "clone failed"; exit 1; }
git -C "$SRC" checkout -q "$REF" || { log "bad ref $REF"; exit 1; }
AUDITED_SHA="$(git -C "$SRC" rev-parse HEAD)"
git -C "$SRC" remote remove origin 2>/dev/null || true    # no push path for tools
# The prompt ships WITH this suite (co-located on the `audits` branch), not in
# the audited code tree — releases stay clean of audit tooling.
PROMPT="${FORK_AUDIT_PROMPT:-$HERE/prompt.md}"
[ -f "$PROMPT" ] || { log "no prompt.md next to run.sh ($PROMPT)"; exit 1; }
log "auditing $AUDITED_SHA · models: $(describe_models)"

TASK="You are auditing the nix-bitcoin fork checked out in the current directory ($SRC), at commit $AUDITED_SHA. Follow your security-audit brief exactly. Map the surface, investigate the highest-value targets, and end with the JSON findings array."

extract_json() { awk '/```json/{buf="";cap=1;next} cap&&/```/{last=buf;cap=0;next} cap{buf=buf $0 "\n"} END{printf "%s",last}' "$1"; }

# Coerce a model's JSON (array | {findings:[...]} | nested) into a flat array of
# finding objects with a coalesced `file` field. Shared by the per-model step.
NORM='def fo: if type=="array" then . elif (type=="object" and ((.findings?|type)=="array")) then .findings else [.. | objects | select(has("title") and has("severity"))] end; fo | map(. + {file:(.file // .location // .component // "?"), line:(.line // 0)})'
# Set when any model produced finding-shaped output we could not parse. A parse
# failure must fail the run loudly, never publish a misleading "0 findings".
PARSE_FAIL=0; FAILED_MODELS=()

for i in "${!MODELS[@]}"; do
  m="${MODELS[$i]}"; prov="${PROVS[$i]}"; mid="${MIDS[$i]}"; think="${THINKS[$i]}"
  raw="$OUT/$m.raw.txt"; fj="$OUT/$m.findings.json"
  log "=== $m ($prov, thinking=$think) ==="
  if [ "$prov" = codex ]; then
    # Codex CLI backend. Same bwrap allowlist as the pi path, plus ~/.local
    # (the codex symlink) read-only and ~/.codex read-write: codex refreshes
    # its ChatGPT OAuth tokens in place, and a discarded refresh would strand
    # the operator's login. Residual, same class as the Fireworks key: the
    # model's shell can read its own auth.json — the token values are scrubbed
    # from every published file below. `-s read-only` is codex's own sandbox;
    # web search is disabled so a fetched page cannot prompt-inject the model.
    { cat "$PROMPT"; printf '\n\n%s\n' "$TASK"; } > "$OUT/.$m.prompt.md"
    ( cd "$SRC" && timeout "${FORK_AUDIT_TIMEOUT:-3600}" \
        bwrap \
          --ro-bind / / --dev /dev --proc /proc --bind /tmp /tmp --unshare-pid \
          --tmpfs "$HOME" \
          --ro-bind "$HOME/.local" "$HOME/.local" \
          --bind "$HOME/.codex" "$HOME/.codex" \
          --ro-bind "$SRC" "$SRC" \
          --chdir "$SRC" \
          -- codex exec -m "$mid" -c "model_reasoning_effort=$think" -c 'web_search="disabled"' \
               -s read-only --ephemeral --skip-git-repo-check --color never \
               -o "/tmp/fork-audit-$STAMP.$m.last" - < "$OUT/.$m.prompt.md" ) > "$raw" 2>&1
    rc=$?; [ "$rc" -eq 0 ] || log "$m exited nonzero ($rc; partial output kept)"
    # -o must land inside a bind (/tmp): $HOME is a tmpfs inside the sandbox.
    mv -f "/tmp/fork-audit-$STAMP.$m.last" "$OUT/$m.last.txt" 2>/dev/null || :
    # codex exec streams the transcript on stderr and only the final message on
    # stdout, so both are merged into $raw (the published transcript).
    # Findings come from the final message; fall back to the transcript, and
    # accept a bare JSON document when the model skipped the fence.
    extract_json "$OUT/$m.last.txt" > "$fj.raw" 2>/dev/null
    [ -s "$fj.raw" ] || extract_json "$raw" > "$fj.raw"
    [ -s "$fj.raw" ] || { grep -qE '^[[:space:]]*[[{]' "$OUT/$m.last.txt" 2>/dev/null && cp "$OUT/$m.last.txt" "$fj.raw"; }
  else
  # Run the model inside a bwrap sandbox. Allowlist, not denylist: the whole of
  # $HOME is masked with a tmpfs, and ONLY what the audit needs is re-exposed —
  # pi's binary (~/.npm-global, read-only), pi's config (~/.pi/agent, via a
  # throwaway overlay so a run can't tamper with your interactive pi), and the
  # read-only fork checkout. So the model's shell sees none of the operator's
  # other secrets (SSH keys, ~/.config, ~/Documents/lnd creds, ~/.bitcoin, …).
  # --unshare-pid gives it its own PID namespace, so it cannot read other
  # processes' /proc/<pid>/environ. Network stays shared (pi must reach
  # Fireworks); the only reachable secret is the low-impact Fireworks key in the
  # env — bound it with a Fireworks spend cap (the residual is quota abuse, not
  # funds/keys). This sandbox wraps ONLY the audit's pi call; interactive pi is
  # untouched.
  ( cd "$SRC" && timeout "${FORK_AUDIT_TIMEOUT:-3600}" \
      bwrap \
        --ro-bind / / --dev /dev --proc /proc --bind /tmp /tmp --unshare-pid \
        --tmpfs "$HOME" \
        --ro-bind "$HOME/.npm-global" "$HOME/.npm-global" \
        --ro-bind "$SRC" "$SRC" \
        --overlay-src "$HOME/.pi/agent" --tmp-overlay "$HOME/.pi/agent" \
        --chdir "$SRC" \
        -- pi -p --provider "$prov" --model "$mid:$think" --tools "$TOOLS" \
             --append-system-prompt "$PROMPT" "$TASK" ) > "$raw" 2> "$OUT/$m.stderr"
  rc=$?; [ "$rc" -eq 0 ] || log "$m exited nonzero ($rc; partial output kept)"
  extract_json "$raw" > "$fj.raw"
  fi
  # Normalize any shape a model actually emits into a flat array of finding
  # objects: a bare array, {"findings":[...]}, or (fallback) any nested objects
  # that carry title+severity. Coalesce the location field (models variously use
  # file / location / component). A model that deviates from the array contract
  # must NEVER be read as "0 findings" — that silent fail-open is the exact bug
  # this audit is meant to catch, and it once hid a high-severity finding.
  if have jq && jq -e "$NORM" "$fj.raw" >/dev/null 2>&1; then
    jq "$NORM" "$fj.raw" > "$fj"
    n=$(jq 'length' "$fj")
    if [ "$n" -eq 0 ] && grep -qE '"(severity|title)"[[:space:]]*:' "$fj.raw"; then
      log "$m: PARSE MISMATCH — raw carries findings but normalized to 0"; PARSE_FAIL=1
    else
      log "$m: $n findings"
    fi
  else
    # No parseable JSON block. Acceptable only if the model truly emitted nothing
    # finding-shaped; otherwise fail loud rather than publish a false clean.
    echo '[]' > "$fj"
    if grep -qE '"(severity|title)"[[:space:]]*:' "$raw"; then
      log "$m: PARSE FAIL — findings in raw but no parseable JSON block"; PARSE_FAIL=1
    elif [ "$rc" -ne 0 ] || grep -qiE '^ERROR:|content was flagged|rate limit|quota|unauthori[sz]ed' "$raw" "$OUT/$m.stderr" 2>/dev/null; then
      # The model never delivered a verdict (crashed, refused, was blocked by a
      # provider policy filter). Publishing that as "0 findings" is the
      # fail-open this audit exists to catch — treat it exactly like a parse
      # failure: banner, incomplete counts, nonzero exit.
      log "$m: MODEL FAILED — no verdict delivered (exit $rc)"; PARSE_FAIL=1
      FAILED_MODELS+=("$m")
    else
      log "$m: no findings (empty)"
    fi
  fi
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
  echo "- Models: $(describe_models)"
  echo "- Prompt: the exact brief used is saved next to this report as \`prompt.used.md\`"
  echo "- Findings: **$total** total · $crit critical · $high high · $corrob flagged by >1 model"; echo
  [ "$PARSE_FAIL" -ne 0 ] && echo "> ⚠ INCOMPLETE — at least one model failed or its findings could not be parsed${FAILED_MODELS[*]:+ (no verdict from: ${FAILED_MODELS[*]})}. The counts above are NOT a clean result. Read the per-model transcripts before trusting this report." && echo
  echo "> LLM findings gate the release: the audit must complete and be reviewed before shipping."; echo
  if have jq && [ "${total:-0}" != 0 ]; then
    jq -r --argjson o '{"critical":0,"high":1,"medium":2,"low":3,"info":4}' 'sort_by($o[.severity]//9)|.[]|
      "## [\(.severity)] \(.title)\n- model: \(.model) · confidence: \(.confidence) · \(.category)\n- \(.file):\(.line)\n- attack: \(.attack_scenario)\n- fix: \(.recommendation)\n"' "$MERGED" 2>/dev/null \
    || jq -r '.[]|"- [\(.severity)] \(.title) (\(.model)) — \(.file):\(.line)"' "$MERGED"
  else echo "No parseable findings — see the per-model transcripts."; fi
} > "$REPORT"
log "report: $REPORT"

# --- SECRET SCRUB (defense in depth; the sandbox is the primary control) -----
# The bwrap sandbox already hides the SSH deploy/sign keys and the secrets file
# from the model, and only the low-impact Fireworks key is reachable in its env.
# This is the second line before publishing:
#   (a) fail closed if a real PEM private-key BLOCK appears — matched by the
#       actual "-----BEGIN … PRIVATE KEY-----" header, NOT prose that merely
#       says "private key" (findings legitimately discuss keys). Checked first,
#       before any redaction could mask a header.
#   (b) redact known secret VALUES (every line, so a multi-line body is fully
#       covered) and fail closed if any survives.
PUBFILES=("$REPORT" "$MERGED"); for m in "${MODELS[@]}"; do PUBFILES+=("$OUT/$m.findings.json" "$OUT/$m.raw.txt"); done
LEAK=0
# PEM blocks: a real private key anywhere blocks publishing; the fork's
# deliberately public demo key (examples/qemu-vm/id-vm, allowlisted in
# public-keys.allow) is replaced by a placeholder instead.
python3 "$HERE/pem-check.py" "$HERE/public-keys.allow" "${PUBFILES[@]}" || { log "PRIVATE-KEY BLOCK — refusing to publish"; LEAK=1; }
secrets=("${FIREWORKS_API_KEY:-}" "${OPENAI_API_KEY:-}" "${BRAVE_API_KEY:-}" "${EXA_API_KEY:-}" "${RESEND_API_KEY:-}")
# Codex CLI OAuth material (reachable by the codex-backed model's shell).
if [ -f "$HOME/.codex/auth.json" ] && have jq; then
  while IFS= read -r tok; do [ -n "$tok" ] && secrets+=("$tok"); done \
    < <(jq -r '[.OPENAI_API_KEY?, .tokens.access_token?, .tokens.refresh_token?, .tokens.id_token?] | .[] | select(. != null and . != "")' "$HOME/.codex/auth.json" 2>/dev/null)
fi
for k in "$DEPLOY_KEY" "$SIGN_KEY"; do [ -f "$k" ] && secrets+=("$(cat "$k")"); done
redact_lines() {  # $1=secret value (maybe multi-line), $2=file
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # PEM armor lines are not secret material; redacting them would only
    # blind the PEM check and mangle innocent transcripts.
    case "$line" in -----BEGIN*|-----END*) continue;; esac
    esc=$(printf '%s' "$line" | sed 's/[#&/\\]/\\&/g'); sed -i "s#${esc}#[REDACTED]#g" "$2"
  done < <(printf '%s\n' "$1")
}
for f in "${PUBFILES[@]}"; do [ -f "$f" ] || continue
  for s in "${secrets[@]}"; do [ -n "$s" ] || continue; redact_lines "$s" "$f"; done
done
for f in "${PUBFILES[@]}"; do [ -f "$f" ] || continue
  for s in "${secrets[@]}"; do [ -n "$s" ] || continue
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "$line" in -----BEGIN*|-----END*) continue;; esac
      if grep -Fq -- "$line" "$f"; then log "SECRET VALUE present in $f — refusing to publish"; LEAK=1; fi
    done < <(printf '%s\n' "$s")
  done
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
  cp "$PROMPT" "$dst/prompt.used.md"
  for m in "${MODELS[@]}"; do cp "$OUT/$m.findings.json" "$OUT/$m.raw.txt" "$dst"/ 2>/dev/null; done
  git -C "$pub" add -A
  git -C "$pub" commit -q -m "audit $STAMP — ${AUDITED_SHA:0:12} — $total findings ($crit crit/$high high)" || { log "nothing to publish"; return; }
  if git -C "$pub" push -q origin audits; then log "published to audits branch: runs/$STAMP"; else log "publish push failed"; fi
}
publish

# --- second opinion --------------------------------------------------------
# GPT-6 Astra (Codex CLI) re-reads the cited code and grades every finding
# (see second-opinion.sh). Off with FORK_AUDIT_SECOND_OPINION=0. It cannot run
# the adversarial brief itself (OpenAI's cyber classifier), so this is how the
# third model contributes.
if [ "${FORK_AUDIT_SECOND_OPINION:-codex/gpt-6-astra:xhigh}" != 0 ] && [ "$total" -gt 0 ] && [ -x "$HERE/second-opinion.sh" ]; then
  "$HERE/second-opinion.sh" "$STAMP" "${FORK_AUDIT_SECOND_OPINION:-codex/gpt-6-astra:xhigh}" || log "second opinion did not complete"
fi

# --- email -----------------------------------------------------------------
if [ -n "${RESEND_API_KEY:-}" ] && have jq && [ "$LEAK" = 0 ]; then
  if curl -sS -m 30 https://api.resend.com/emails -H "Authorization: Bearer $RESEND_API_KEY" -H "Content-Type: application/json" \
       -d "$(jq -n --arg f "$ALERT_FROM" --arg t "$ALERT_TO" --arg s "[fork-audit] $total findings ($crit crit/$high high) @ ${AUDITED_SHA:0:8}" --arg b "$(cat "$REPORT")" '{from:$f,to:[$t],subject:$s,text:$b}')" >/dev/null
  then log "emailed $ALERT_TO"; else log "email failed"; fi
fi
log "done — $OUT"

# Fail loud if any model's findings could not be parsed. The report and the
# recovered findings are still published above, but a nonzero exit stops a
# caller (gate/CI) from reading this run as a clean pass.
if [ "$PARSE_FAIL" -ne 0 ]; then
  log "EXIT NONZERO — parse failure in at least one model; results are incomplete"
  exit 3
fi
