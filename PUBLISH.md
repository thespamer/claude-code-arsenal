# Publishing this repository

Step-by-step for putting `claude-code-arsenal` on GitHub under your account.

## Prerequisites

- `git` installed and configured (`git config --global user.name` and `user.email` set)
- `gh` (GitHub CLI) installed and authenticated (`gh auth login`, browser flow)

## Steps

```bash
# 1. From inside the unzipped folder
cd claude-code-arsenal

# 2. Initialize and commit
git init
git add .
git commit -m "feat: initial release of claude-code-arsenal with 6 subagents"
git branch -M main

# 3. Create the remote and push (replace USERNAME if not thespamer)
gh repo create thespamer/claude-code-arsenal \
  --public \
  --description "Six specialized Claude Code subagents: architect, security-auditor, cost-sentinel, test-fixer, dependency-detective, commit-curator" \
  --source=. \
  --remote=origin \
  --push

# 4. Add discovery topics
gh repo edit thespamer/claude-code-arsenal \
  --add-topic claude-code \
  --add-topic claude-code-subagents \
  --add-topic ai-agents \
  --add-topic developer-tools \
  --add-topic devtools

# 5. (Optional) Tag a release
git tag -a v1.0.0 -m "v1.0.0 — initial release with 6 subagents"
git push origin v1.0.0
gh release create v1.0.0 \
  --title "v1.0.0 — initial release" \
  --notes "Six specialized Claude Code subagents for daily engineering work. See README for install and usage."
```

## After publish

Open the repo URL and confirm:

- README renders cleanly
- `agents/` lists six markdown files
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
