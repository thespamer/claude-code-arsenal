#!/usr/bin/env bash
#
# verify-manifest.sh — Confirm the README permission table matches each agent's
# YAML frontmatter. Fails (exit 1) on drift.
#
# The README declares three boolean permissions per agent:
#   - FS writes  (yes iff `tools:` contains Write or Edit)
#   - Shell exec (yes iff `tools:` contains Bash)
#   - Network    (yes iff `tools:` contains WebFetch or WebSearch)
#
# This script derives the "actual" answer from each agent's frontmatter and
# compares it to what the README claims. Any mismatch is a hard error.
#
# Usage:
#   tools/verify-manifest.sh          # runs against the whole repo
#   tools/verify-manifest.sh --quiet  # only prints on error
#
# Exit codes:
#   0 = clean
#   1 = drift detected
#   2 = missing files / setup error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO_ROOT/README.md"
AGENTS_DIR="$REPO_ROOT/agents"

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

log() { [[ $QUIET -eq 0 ]] && echo "$@" || true; }
err() { echo "ERROR: $*" >&2; }

# ---------- Precondition checks ----------

[[ -f "$README" ]] || { err "README.md not found at $README"; exit 2; }
[[ -d "$AGENTS_DIR" ]] || { err "agents/ dir not found at $AGENTS_DIR"; exit 2; }

# ---------- Extract permissions from each agent frontmatter ----------

declare -A ACTUAL_FS_WRITES
declare -A ACTUAL_SHELL_EXEC
declare -A ACTUAL_NETWORK

extract_from_frontmatter() {
    local agent_file="$1"
    local agent_name
    agent_name="$(basename "$agent_file" .md)"

    # Skip the conventions file itself
    [[ "$agent_name" == "AGENT-CONVENTIONS" ]] && return 0

    # Extract the tools: line from frontmatter (between the two --- markers)
    local tools_line
    tools_line="$(awk '/^---$/{c++; next} c==1 && /^tools:/{print; exit}' "$agent_file")"

    if [[ -z "$tools_line" ]]; then
        err "$agent_name: no 'tools:' field in frontmatter"
        return 1
    fi

    # Normalize the tools list into a single lowercased string for grepping
    local tools_lower
    tools_lower="$(echo "$tools_line" | tr '[:upper:]' '[:lower:]')"

    ACTUAL_FS_WRITES[$agent_name]="No"
    if echo "$tools_lower" | grep -qE 'write|edit'; then
        ACTUAL_FS_WRITES[$agent_name]="Yes"
    fi

    ACTUAL_SHELL_EXEC[$agent_name]="No"
    if echo "$tools_lower" | grep -qE 'bash'; then
        ACTUAL_SHELL_EXEC[$agent_name]="Yes"
    fi

    ACTUAL_NETWORK[$agent_name]="No"
    if echo "$tools_lower" | grep -qE 'webfetch|websearch'; then
        ACTUAL_NETWORK[$agent_name]="Yes"
    fi
}

for agent_file in "$AGENTS_DIR"/*.md; do
    extract_from_frontmatter "$agent_file"
done

# ---------- Extract permissions claimed by the README table ----------

declare -A README_FS_WRITES
declare -A README_SHELL_EXEC
declare -A README_NETWORK

# The README table looks like:
# | `agent-name` | Job description | FS writes | Shell exec | Network | Model |
# Extract via awk, matching lines that start with | ` and have >= 6 pipe-separated cells

parse_readme_table() {
    awk -F'|' '
        # Only consider lines that look like data rows for our agents
        /^\| `[a-z-]+` \|/ {
            # Fields: 1=empty(before first |), 2=agent, 3=job, 4=fs, 5=shell, 6=net, 7=model
            # Strip whitespace and backticks
            agent = $2
            gsub(/[` ]/, "", agent)

            fs = $4;    gsub(/^ +| +$/, "", fs)
            shell = $5; gsub(/^ +| +$/, "", shell)
            net = $6;   gsub(/^ +| +$/, "", net)

            # Only keep the first word (Yes / No), some cells have parenthetical detail
            sub(/ .*/, "", fs)
            sub(/ .*/, "", shell)
            sub(/ .*/, "", net)

            print agent "|" fs "|" shell "|" net
        }
    ' "$README"
}

while IFS='|' read -r agent fs shell net; do
    [[ -z "$agent" ]] && continue
    README_FS_WRITES[$agent]="$fs"
    README_SHELL_EXEC[$agent]="$shell"
    README_NETWORK[$agent]="$net"
done < <(parse_readme_table)

# ---------- Compare ----------

DRIFT=0
DRIFT_REPORT=""

check_agent() {
    local agent="$1"
    local dim="$2"       # human-readable dimension name
    local actual="$3"
    local claimed="$4"

    if [[ "$actual" != "$claimed" ]]; then
        DRIFT=1
        DRIFT_REPORT+="  - ${agent} / ${dim}: frontmatter says '${actual}', README claims '${claimed}'"$'\n'
    fi
}

for agent in "${!ACTUAL_FS_WRITES[@]}"; do
    if [[ -z "${README_FS_WRITES[$agent]+isset}" ]]; then
        DRIFT=1
        DRIFT_REPORT+="  - ${agent}: present in agents/ but missing from README table"$'\n'
        continue
    fi
    check_agent "$agent" "FS writes"  "${ACTUAL_FS_WRITES[$agent]}"  "${README_FS_WRITES[$agent]}"
    check_agent "$agent" "Shell exec" "${ACTUAL_SHELL_EXEC[$agent]}" "${README_SHELL_EXEC[$agent]}"
    check_agent "$agent" "Network"    "${ACTUAL_NETWORK[$agent]}"    "${README_NETWORK[$agent]}"
done

for agent in "${!README_FS_WRITES[@]}"; do
    if [[ -z "${ACTUAL_FS_WRITES[$agent]+isset}" ]]; then
        DRIFT=1
        DRIFT_REPORT+="  - ${agent}: listed in README table but no agents/${agent}.md file"$'\n'
    fi
done

# ---------- Report ----------

if [[ $DRIFT -eq 0 ]]; then
    log "OK: README permission table matches all agent frontmatters."
    exit 0
else
    echo "DRIFT DETECTED between README and agent frontmatters:" >&2
    echo "$DRIFT_REPORT" >&2
    echo "Fix: update README.md or the offending agent's 'tools:' field." >&2
    echo "Both must agree; the frontmatter is the source of truth, but the README table must reflect it." >&2
    exit 1
fi
