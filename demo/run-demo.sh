#!/usr/bin/env bash
#
# run-demo.sh — Set up the demo environment and print the sequence of
# prompts you should paste into Claude Code to exercise all six agents.
#
# Usage:
#   ./run-demo.sh setup    # install agents user-level, set up venv, init git
#   ./run-demo.sh prompts  # print the ordered list of prompts to paste

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo/pyorders"

setup() {
    echo "==> Installing the six subagents to ~/.claude/agents/"
    mkdir -p "$HOME/.claude/agents"
    cp "$REPO_ROOT/agents/"*.md "$HOME/.claude/agents/"
    ls "$HOME/.claude/agents/" | grep -E "(architect|security-auditor|cost-sentinel|test-fixer|dependency-detective|commit-curator)\.md"

    echo
    echo "==> Setting up the demo project at $DEMO_DIR"
    cd "$DEMO_DIR"

    if [ ! -d ".venv" ]; then
        python3 -m venv .venv
    fi
    # shellcheck disable=SC1091
    source .venv/bin/activate
    pip install --quiet --upgrade pip
    pip install --quiet pytest fastapi pyjwt psycopg2-binary requests

    if [ ! -d ".git" ]; then
        git init --quiet
        git add .
        git commit --quiet -m "chore: initial demo skeleton"
    fi

    echo
    echo "==> Verifying the failing test is in place"
    set +e
    .venv/bin/pytest tests/ -v --tb=line 2>&1 | tail -10
    set -e

    echo
    echo "==> Ready. Now run \`claude\` inside $DEMO_DIR and use:"
    echo "    ./run-demo.sh prompts"
}

prompts() {
    cat <<'EOF'

Paste these prompts one at a time into Claude Code, in order:

  1. /agents
     (confirms the six are loaded)

  2. use the architect to review the structure of this project

  3. use the security-auditor to sweep this codebase

  4. use the cost-sentinel on this codebase

  5. (back in your terminal first)
     pytest tests/ -v
     (confirm test_apply_discount_ten_percent_applied_to_subtotal_only fails)
     then in Claude Code:
     use the test-fixer on tests/test_billing.py::test_apply_discount_ten_percent_applied_to_subtotal_only

  6. use the dependency-detective on requirements.txt

  7. (back in your terminal)
     git add src/billing.py
     then in Claude Code:
     use the commit-curator on my staged changes

  8. (bonus — show the curator refusing to bundle unrelated changes)
     git reset
     git add src/billing.py README.md
     then in Claude Code:
     use the commit-curator on my staged changes

For full expected outputs and analysis of each agent's findings, see DEMO.md.
EOF
}

case "${1:-}" in
    setup)   setup ;;
    prompts) prompts ;;
    *)
        echo "Usage: $0 {setup|prompts}"
        exit 1
        ;;
esac
