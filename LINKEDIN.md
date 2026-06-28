# LinkedIn post draft

Two variants. Pick one.

---

## Variant A — builder voice, technical

I shipped a small open-source toolkit: six Claude Code subagents I actually use every day.

Each one has a sharp scope:

▸ `architect` reads the codebase and explains the shape of the system
▸ `security-auditor` sweeps for secrets, IAM gaps, OWASP patterns
▸ `cost-sentinel` flags patterns that look fine in dev and become expensive in prod
▸ `test-fixer` diagnoses failing tests and applies the minimal correct fix
▸ `dependency-detective` audits manifests for vulns, staleness, redundancy
▸ `commit-curator` reads staged diffs and drafts the Conventional Commits message

Four of the six are read-only by design. Findings get reported, humans take action. The one that edits code (`test-fixer`) refuses to touch more than three files.

Apache 2.0. Install is `cp agents/*.md ~/.claude/agents/`.

→ github.com/thespamer/claude-code-arsenal

---

## Variant B — practitioner voice, opinionated

After a year of daily Claude Code, the lesson is simple: the agents that work are the ones with a sharp job description and no permission to do anything else.

So I packaged the six I rely on every day.

The commit-curator alone has paid for itself. It reads the staged diff, classifies the change, refuses to bundle unrelated work into one commit, and writes a Conventional Commits message that an engineer six months from now will actually understand.

The cost-sentinel catches the patterns that do not blow up in staging. N+1 queries, missing indexes, unbounded fanout, NAT Gateway egress, CloudWatch logs without retention. The kind of thing the cloud bill teaches you about, late.

Apache 2.0, install in two lines.

→ github.com/thespamer/claude-code-arsenal

What is in your own subagent folder? Curious what people are running.

---

## Hashtags (pick 3 to 5)

#claudecode #aiagents #developertools #devtools #softwareengineering #opensource #aiops #softwarearchitecture
