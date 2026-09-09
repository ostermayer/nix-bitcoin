#!/usr/bin/env bash
# second-opinion.sh — independent triage of a finished audit run's findings.
#
# GPT-6 Astra (via the locally installed Codex CLI, ChatGPT login) cannot run
# the adversarial brief itself: OpenAI's cyber-safety classifier cuts the
# session (needs Trusted Access for Cyber). It CAN act as the second reviewer:
# given the merged findings of the Fireworks models (Kimi K3 + GLM 5.3), it
# re-reads the cited code at the audited commit and returns, per finding, a
# verdict (confirmed / false-positive / needs-info), a severity call and a
# one-line justification, plus anything obviously wrong or missing in the
# files the findings touch. Output lands next to the run and is published to
# the `audits` branch with it.
#
# Usage: second-opinion.sh <run-stamp> [model-spec]
#        model-spec defaults to codex/gpt-6-astra:xhigh (only codex/ is wired)
# Env:   FORK_AUDIT_NO_PUBLISH=1  FORK_AUDIT_TIMEOUT=3600
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; WORK="${FORK_AUDIT_WORK:-$HERE}"
REPO_HTTPS="https://github.com/ostermayer/nix-bitcoin.git"
REPO_SSH="git@github.com:ostermayer/nix-bitcoin.git"
DEPLOY_KEY="${FORK_AUDIT_KEY:-$HOME/.ssh/id_ed25519_forkautotest}"
SIGN_KEY="${FORK_AUDIT_SIGN_KEY:-$HOME/.ssh/id_ed25519_forkautotest_sign}"
STAMP="${1:?run stamp}"; SPEC="${2:-codex/gpt-6-astra:xhigh}"
OUT="$WORK/reports/$STAMP"; MERGED="$OUT/findings.merged.json"; REPORT="$OUT/report.md"
log() { printf '%s %s\n' "$(date -Is)" "$1"; }
have() { command -v "$1" >/dev/null; }
[ -f "$MERGED" ] && [ -f "$REPORT" ] || { log "no finished run at $OUT"; exit 1; }
think="xhigh"; case "$SPEC" in *:*) think="${SPEC##*:}"; SPEC="${SPEC%:*}";; esac
prov="${SPEC%%/*}"; mid="${SPEC#*/}"; m="${mid##*/}"
[ "$prov" = codex ] || { log "only the codex/ backend is wired for second opinions"; exit 1; }
n=$(jq 'length' "$MERGED"); [ "$n" -gt 0 ] || { log "run has 0 findings — nothing to second-guess"; exit 0; }
SHA=$(sed -nE 's/^- Commit audited: `([0-9a-f]+)`.*/\1/p' "$REPORT" | head -1)
[ -n "$SHA" ] || { log "cannot read audited commit from $REPORT"; exit 1; }

RAW="$OUT/second-opinion.$m.raw.txt"; LAST="$OUT/second-opinion.$m.last.txt"
rc=0
if [ "${SO_RENDER_ONLY:-0}" = 1 ] && { [ -s "$LAST" ] || [ -s "$RAW" ]; }; then
  log "render-only: reusing $LAST"
else
# Read-only, credential-free checkout of the audited commit (own dir: a live
# run.sh may be using another).
SRC="$WORK/src-so-$STAMP"; rm -rf "$SRC"; trap 'rm -rf "$SRC"' EXIT
git clone -q "$REPO_HTTPS" "$SRC" && git -C "$SRC" checkout -q "$SHA" || { log "checkout of $SHA failed"; exit 1; }
git -C "$SRC" remote remove origin 2>/dev/null || true

PROMPT="$OUT/.second-opinion.$m.prompt.md"
{
cat <<'BRIEF'
You are the second reviewer on a routine security code review of our own
nix-bitcoin fork: the NixOS modules and packaging we deploy on our own Bitcoin
and Lightning node. Two prior reviewers have already produced the findings
below against the exact commit checked out in the current directory. Your job
is quality control on their work, as the maintainer's independent check:

For EACH finding, open the cited file at the cited location and decide:
- verdict: "confirmed" (the defect is real as described), "false-positive"
  (the code does not do what the finding claims, or an existing control
  already prevents it — name the control), or "needs-info" (cannot be decided
  from the tree; say what is missing).
- severity: your own call (critical/high/medium/low/info), which may differ
  from the reviewer's.
- reasoning: one to three sentences grounded in the code you read (quote the
  line or construct that decides it).
- fix_ok: whether the reviewer's recommended fix is correct and complete
  (true/false) and, if false, what is wrong with it.

Then, only for the files the findings touch, note up to three defects the
reviewers missed or misread that a maintainer should know about ("missed").
Do not pad: if there is nothing, say so.

Read-only tools only; do not modify the tree. Be terse and concrete.

End your answer with exactly one fenced ```json block of this shape:
{"reviews":[{"id":"<finding id or title>","verdict":"confirmed|false-positive|needs-info","severity":"...","reasoning":"...","fix_ok":true,"fix_note":""}],
 "missed":[{"file":"...","line":0,"severity":"...","title":"...","description":"..."}],
 "summary":"two or three sentences"}
followed by nothing else.
BRIEF
printf '\n## The findings under review (commit %s)\n\n```json\n' "$SHA"
jq '[.[] | {id, title, severity, confidence, model, file, line, description, impact, recommendation}]' "$MERGED"
printf '```\n'
} > "$PROMPT"

log "second opinion on $STAMP ($n findings, commit ${SHA:0:12}) · $m via $prov, thinking=$think"
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
           -o "/tmp/fork-audit-so-$STAMP.last" - < "$PROMPT" ) > "$RAW" 2>&1
rc=$?
# -o must point inside a bind (/tmp): $HOME is a tmpfs in the sandbox, so a
# path under $OUT would be written into the void.
mv -f "/tmp/fork-audit-so-$STAMP.last" "$LAST" 2>/dev/null || :
fi

extract_json() { awk '/```json/{buf="";cap=1;next} cap&&/```/{last=buf;cap=0;next} cap{buf=buf $0 "\n"} END{printf "%s",last}' "$1"; }
JSON="$OUT/second-opinion.$m.json"; MD="$OUT/second-opinion.$m.md"
extract_json "$LAST" > "$JSON.raw" 2>/dev/null; [ -s "$JSON.raw" ] || extract_json "$RAW" > "$JSON.raw"
STATUS=ok
if [ "$rc" -ne 0 ] || grep -qE '^ERROR:|content was flagged for possible cybersecurity risk' "$RAW"; then STATUS=failed; fi
if ! jq -e '.reviews | type=="array"' "$JSON.raw" >/dev/null 2>&1; then [ "$STATUS" = ok ] && STATUS=unparsed; echo '{"reviews":[],"missed":[],"summary":""}' > "$JSON"; else jq . "$JSON.raw" > "$JSON"; fi

{
  echo "# Second opinion — $m ($prov, thinking=$think) on run $STAMP"; echo
  echo "- Commit reviewed: \`$SHA\`"; echo "- Findings reviewed: $n"; echo "- Status: **$STATUS**"
  if [ "$STATUS" != ok ]; then
    echo; echo "> ⚠ The second opinion did NOT complete (exit $rc). Treat the primary findings as un-reviewed."
    grep -E '^ERROR:' "$RAW" | head -3 | sed 's/^/> /'
  fi
  echo
  echo "| Finding | Reviewer says | Astra verdict | Astra severity | Fix OK | Reasoning |"; echo "|---|---|---|---|---|---|"
  jq -r --slurpfile f "$MERGED" '
    ($f[0] | map({key:(.id // .title), value:.}) | from_entries) as $by
    | .reviews[] | ($by[.id] // ($f[0][] | select(.title==.id))) as $orig
    | "| \(.id) | \(($orig.severity // "?")) (\($orig.model // "?")) | **\(.verdict)** | \(.severity) | \(.fix_ok) \(.fix_note // "" | if .=="" then "" else "— " + . end) | \(.reasoning | gsub("\\|";"/") | gsub("\n";" ")) |"' "$JSON" 2>>"$OUT/.second-opinion.err"
  echo
  if [ "$(jq '.missed|length' "$JSON")" -gt 0 ]; then
    echo "## Missed / misread (per Astra)"; echo
    jq -r '.missed[] | "- [\(.severity)] **\(.title)** — \(.file):\(.line)\n  \(.description)"' "$JSON"; echo
  fi
  s=$(jq -r '.summary // ""' "$JSON"); [ -n "$s" ] && { echo "## Summary"; echo; echo "$s"; echo; }
  echo "_Advisory input to human triage, like the primary findings. Full transcript: \`second-opinion.$m.raw.txt\`._"
} > "$MD"
# pointer in the main report
grep -q "second-opinion.$m.md" "$REPORT" || printf '\n> Second opinion by %s (%s, thinking=%s): **%s** — see `second-opinion.%s.md`.\n' "$m" "$prov" "$think" "$STATUS" "$m" >> "$REPORT"
log "second opinion: $STATUS — $MD"

# --- scrub + publish (same rules as run.sh) ---------------------------------
PUBFILES=("$MD" "$JSON" "$RAW" "$REPORT")
secrets=()
if [ -f "$HOME/.codex/auth.json" ] && have jq; then
  while IFS= read -r tok; do [ -n "$tok" ] && secrets+=("$tok"); done \
    < <(jq -r '[.OPENAI_API_KEY?, .tokens.access_token?, .tokens.refresh_token?, .tokens.id_token?] | .[] | select(. != null and . != "")' "$HOME/.codex/auth.json" 2>/dev/null)
fi
for k in "$DEPLOY_KEY" "$SIGN_KEY"; do [ -f "$k" ] && secrets+=("$(cat "$k")"); done
LEAK=0
# PEM blocks: a real private key anywhere blocks publishing; the fork's
# deliberately public demo key (examples/qemu-vm/id-vm, allowlisted in
# public-keys.allow) is replaced by a placeholder instead.
python3 "$HERE/pem-check.py" "$HERE/public-keys.allow" "${PUBFILES[@]}" || LEAK=1
for f in "${PUBFILES[@]}"; do
  for s in "${secrets[@]}"; do
    while IFS= read -r line; do [ -n "$line" ] || continue
      # PEM armor lines are not secret material; redacting them would only
      # blind the PEM check above and mangle innocent transcripts.
      case "$line" in -----BEGIN*|-----END*) continue;; esac
      esc=$(printf '%s' "$line" | sed 's/[#&/\\]/\\&/g'); sed -i "s#${esc}#[REDACTED]#g" "$f"
      grep -Fq -- "$line" "$f" && { log "SECRET VALUE present in $f"; LEAK=1; }
    done < <(printf '%s\n' "$s")
  done
done
[ "$LEAK" = 0 ] && log "secret scrub clean" || log "secret scrub FAILED — publish blocked"
if [ "${FORK_AUDIT_NO_PUBLISH:-0}" != 1 ] && [ "$LEAK" = 0 ]; then
  pub="$WORK/publish"; export GIT_SSH_COMMAND="ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  [ -d "$pub/.git" ] || git clone -q "$REPO_SSH" "$pub"
  git -C "$pub" fetch -q origin && git -C "$pub" checkout -q -B audits origin/audits
  git -C "$pub" config user.name "fork-autotest"; git -C "$pub" config user.email "ostermayer@users.noreply.github.com"
  [ -f "$SIGN_KEY.pub" ] && { git -C "$pub" config gpg.format ssh; git -C "$pub" config user.signingkey "$SIGN_KEY.pub"; git -C "$pub" config commit.gpgsign true; }
  dst="$pub/runs/$STAMP"; mkdir -p "$dst"; cp "$MD" "$JSON" "$RAW" "$REPORT" "$dst"/
  git -C "$pub" add -A && git -C "$pub" commit -q -m "audit $STAMP — second opinion by $m: $STATUS" \
    && git -C "$pub" push -q origin audits && log "published second opinion: runs/$STAMP" || log "publish failed or nothing to publish"
fi
[ "$STATUS" = ok ] || exit 3
