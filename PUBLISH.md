# Publishing this repository

Step-by-step for forking or re-publishing `claude-code-arsenal` under your own GitHub account.

## Prerequisites

- `git` installed and configured (`git config --global user.name` and `user.email` set)
- `gh` (GitHub CLI) installed and authenticated (`gh auth login`, browser flow)

## Steps

The commands below resolve your GitHub username automatically from `gh` — no hardcoded values.

```bash
# 0. Resolve your GitHub username (used throughout this script)
GH_USER=$(gh api user --jq .login)
echo "Publishing as: $GH_USER"

# 1. From inside the repository folder
cd claude-code-arsenal

# 2. Initialize and commit (skip if already a git repo)
git init
git add .
git commit -m "feat: initial release of claude-code-arsenal with 6 subagents"
git branch -M main

# 3. Create the remote and push
gh repo create "$GH_USER/claude-code-arsenal" \
  --public \
  --description "Six specialized Claude Code subagents: architect, security-auditor, cost-sentinel, test-fixer, dependency-detective, commit-curator" \
  --source=. \
  --remote=origin \
  --push

# 4. Add discovery topics
gh repo edit "$GH_USER/claude-code-arsenal" \
  --add-topic claude-code \
  --add-topic claude-code-subagents \
  --add-topic ai-agents \
  --add-topic developer-tools \
  --add-topic devtools

# 5. (Optional) Tag a release
git tag -a v1.1.0 -m "v1.1.0 — post-validation improvements"
git push origin v1.1.0
gh release create v1.1.0 \
  --title "v1.1.0 — post-validation improvements" \
  --notes "See CHANGELOG or GitHub release notes."
```

## After publish

Open `https://github.com/$GH_USER/claude-code-arsenal` and confirm:

- README renders cleanly with the permission table
- `agents/` lists seven markdown files (six agents + `AGENT-CONVENTIONS.md`)
- LICENSE is recognized as Apache 2.0 by GitHub
- Topics show on the right sidebar

## Verify the agents work

```bash
# Install user-level
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/

# Open Claude Code in any project, then:
#   /agents          → confirms six are listed
#   > use the commit-curator on my staged changes   → fastest smoke test
```

## Verify manifest and README agree

Run the shipped consistency check to confirm the README permission table matches each agent's `tools:` frontmatter:

```bash
tools/verify-manifest.sh
```

Exit code 0 means clean. Non-zero means drift — the README or the frontmatter changed without the other being updated. Fix before shipping.
