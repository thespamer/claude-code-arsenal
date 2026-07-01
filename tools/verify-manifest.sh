#!/usr/bin/env bash
# verify-manifest.sh — Confirm README permission table matches agent frontmatters.
# Portable to bash 3.2 (macOS) and bash 4+ (Linux).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO_ROOT/README.md"
AGENTS_DIR="$REPO_ROOT/agents"

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

log() { if [[ $QUIET -eq 0 ]]; then echo "$@"; fi }
err() { echo "ERROR: $*" >&2; }

if [[ ! -f "$README" ]]; then err "README.md not found at $README"; exit 2; fi
if [[ ! -d "$AGENTS_DIR" ]]; then err "agents/ dir not found at $AGENTS_DIR"; exit 2; fi

derive_actual() {
    local agent_file="$1"
    local tools_line
    tools_line="$(awk '/^---$/{c++; next} c==1 && /^tools:/{print; exit}' "$agent_file")"
    if [[ -z "$tools_line" ]]; then echo "MISSING MISSING MISSING"; return; fi
    local tools_lower
    tools_lower="$(echo "$tools_line" | tr '[:upper:]' '[:lower:]')"
    local fs="No"; if echo "$tools_lower" | grep -qE 'write|edit'; then fs="Yes"; fi
    local shell="No"; if echo "$tools_lower" | grep -qE 'bash'; then shell="Yes"; fi
    local net="No"; if echo "$tools_lower" | grep -qE 'webfetch|websearch'; then net="Yes"; fi
    echo "$fs $shell $net"
}

readme_lookup() {
    local agent="$1"
    awk -F'|' -v want="$agent" '
        /^\| `[a-z-]+` \|/ {
            name = $2; gsub(/[` ]/, "", name)
            if (name == want) {
                fs = $4;    gsub(/^ +| +$/, "", fs)
                shell = $5; gsub(/^ +| +$/, "", shell)
                net = $6;   gsub(/^ +| +$/, "", net)
                sub(/ .*/, "", fs); sub(/ .*/, "", shell); sub(/ .*/, "", net)
                print fs, shell, net; exit
            }
        }
    ' "$README"
}

DRIFT=0
DRIFT_REPORT=""
README_AGENTS="$(awk -F'|' '/^\| `[a-z-]+` \|/ { name=$2; gsub(/[` ]/,"",name); print name }' "$README")"

for agent_file in "$AGENTS_DIR"/*.md; do
    agent_name="$(basename "$agent_file" .md)"
    if [[ "$agent_name" == "AGENT-CONVENTIONS" ]]; then continue; fi
    actual="$(derive_actual "$agent_file")"
    readme="$(readme_lookup "$agent_name")"
    if [[ -z "$readme" ]]; then
        DRIFT=1
        DRIFT_REPORT+="  - $agent_name: present in agents/ but missing from README table"$'\n'
        continue
    fi
    read -r a_fs a_shell a_net <<< "$actual"
    read -r r_fs r_shell r_net <<< "$readme"
    if [[ "$a_fs" != "$r_fs" ]]; then
        DRIFT=1
        DRIFT_REPORT+="  - $agent_name / FS writes: frontmatter says '$a_fs', README claims '$r_fs'"$'\n'
    fi
    if [[ "$a_shell" != "$r_shell" ]]; then
        DRIFT=1
        DRIFT_REPORT+="  - $agent_name / Shell exec: frontmatter says '$a_shell', README claims '$r_shell'"$'\n'
    fi
    if [[ "$a_net" != "$r_net" ]]; then
        DRIFT=1
        DRIFT_REPORT+="  - $agent_name / Network: frontmatter says '$a_net', README claims '$r_net'"$'\n'
    fi
    README_AGENTS="$(echo "$README_AGENTS" | grep -v "^${agent_name}\$" || true)"
done

if [[ -n "$README_AGENTS" ]]; then
    while IFS= read -r leftover; do
        if [[ -z "$leftover" ]]; then continue; fi
        DRIFT=1
        DRIFT_REPORT+="  - $leftover: listed in README table but no agents/${leftover}.md file"$'\n'
    done <<< "$README_AGENTS"
fi

if [[ $DRIFT -eq 0 ]]; then
    log "OK: README permission table matches all agent frontmatters."
    exit 0
else
    echo "DRIFT DETECTED between README and agent frontmatters:" >&2
    printf '%s' "$DRIFT_REPORT" >&2
    echo "" >&2
    echo "Fix: update README.md or the offending agent's 'tools:' field." >&2
    echo "Both must agree; the frontmatter is the source of truth, but the README table must reflect it." >&2
    exit 1
fi
