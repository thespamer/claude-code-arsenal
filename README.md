# claude-code-arsenal

Six specialized Claude Code subagents for daily engineering work. Each one has a sharp scope so the main session can delegate without losing context, and each one declares the minimum tools it needs so what runs matches what the manifest promises.

## The six

The permission columns below reflect the `tools:` field in each agent's YAML frontmatter. That frontmatter is the enforceable source of truth — Claude Code only grants an agent the tools it declares. This table is generated to match; a CI check (`tools/verify-manifest.sh`) fails if it ever drifts.

| Agent | Job | FS writes | Shell exec | Network | Model |
|---|---|---|---|---|---|
| `architect` | Map the codebase, surface boundary violations, propose ADRs | No | No | No | sonnet |
| `security-auditor` | Sweep for secrets, IAM, OWASP patterns | No | Yes (grep, scanners) | No | sonnet |
| `cost-sentinel` | Flag patterns that become expensive at production scale | No | No | No | sonnet |
| `test-fixer` | Diagnose and repair failing tests with the minimal change | Yes | Yes (pytest, etc.) | No | sonnet |
| `dependency-detective` | Audit dependencies for vulns, staleness, redundancy, licenses | No | Yes (pip-audit, npm audit) | No | sonnet |
| `commit-curator` | Draft a Conventional Commits message from staged changes | No | Yes (git only) | No | haiku |

**FS writes** = the agent's `tools:` list includes `Write` or `Edit`.
**Shell exec** = the agent's `tools:` list includes `Bash`.
**Network** = the agent's `tools:` list includes `WebFetch` or `WebSearch`.

Only `test-fixer` can modify files. The three agents with shell access need it to run tools they cannot substitute (grep, git, pytest, package auditors); none of the three can write to the filesystem or reach the network.

## See it work in 5 minutes

The `demo/` folder has a small flawed FastAPI project (`pyorders`) seeded with one or more issues per agent. Run the demo end to end:

```bash
git clone https://github.com/thespamer/claude-code-arsenal
cd claude-code-arsenal
./demo/run-demo.sh setup       # installs agents user-level, sets up venv, inits git
cd demo/pyorders
claude                          # start Claude Code
```

Then paste these prompts in order:

```
> use the architect to review the structure of this project
> use the security-auditor to sweep this codebase
> use the cost-sentinel on this codebase
> use the test-fixer on tests/test_billing.py::test_apply_discount_ten_percent_applied_to_subtotal_only
> use the dependency-detective on requirements.txt
```

The `test-fixer` will modify `src/billing.py`. Before invoking the last agent, switch to a terminal and stage that change so the curator has something to read:

```bash
git add src/billing.py
```

Then back in Claude Code:

```
> use the commit-curator on my staged changes
```

Each agent produces a real, specific finding (SQL injection in three places, N+1 against a paid API, a `requests==2.18.0` CVE, a real bug in `apply_discount`, etc). Full expected outputs and the rationale for each finding are in [`demo/DEMO.md`](demo/DEMO.md).

Sample of the `architect` agent running against the demo project:

![architect agent output](demo/screenshots/architect-output.png)

The `demo/pyorders/README.md` lists every seeded issue with its file and line so you can verify the agents catch what they should.

## Install

### User-level (available in every project)

```bash
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/
```

### Project-level (versioned with the repo)

```bash
mkdir -p .claude/agents
cp agents/*.md .claude/agents/
git add .claude/agents
```

Project-level takes precedence over user-level when names collide.

## Verify

Open Claude Code in any project and run:

```
/agents
```

You should see all six listed under either Personal or Project scope.

## Use

Claude Code routes to subagents automatically based on the `description` field. You can also invoke them explicitly:

```
> use the architect to review the overall structure of this repo
> use the security-auditor to sweep this codebase before the release
> use the cost-sentinel on services/billing.py before we ship
> use the test-fixer on tests/test_pricing.py::test_discount_applied
> use the dependency-detective on package.json
> use the commit-curator on my staged changes
```

The `commit-curator` is the one you will invoke most often. The others fire when their description matches what you are doing.

## Design principles

- **Manifest is the source of truth.** What an agent can do is determined by the `tools:` field in its YAML frontmatter, not by prose in the README. The README table is derived from the frontmatter and enforced by `tools/verify-manifest.sh` — if they ever drift, CI fails. Labels like "read-only" alone are not enforcement, they are documentation; the frontmatter is enforcement.
- **Minimal filesystem writes.** Five of six agents cannot write to the filesystem (no `Write` or `Edit` in their `tools:` list). They report findings; humans take action. Only `test-fixer` edits code, and it refuses to touch more than three files.
- **One agent, one job.** No agent crosses categories. Each has an "Out of scope" section naming which peer agent handles adjacent concerns. If a job needs three perspectives, run three agents.
- **No fabricated findings.** Every output points at a file and a line. CVE numbers, version numbers, and dollar figures come from real tools or are flagged as estimates with stated assumptions.
- **Honest stop conditions.** If the codebase is too small, the diff is empty, or the change is too large, the agent stops instead of guessing.

## Repository layout

```
claude-code-arsenal/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── PUBLISH.md
├── agents/
│   ├── AGENT-CONVENTIONS.md    # shared guardrails, inherited by all six
│   ├── architect.md
│   ├── commit-curator.md
│   ├── cost-sentinel.md
│   ├── dependency-detective.md
│   ├── security-auditor.md
│   └── test-fixer.md
├── tools/
│   └── verify-manifest.sh      # checks README table ↔ tools: frontmatter agreement
├── .github/
│   └── workflows/
│       └── verify-manifest.yml # runs the check on push/PR to agents/ or README
└── demo/
    ├── DEMO.md                 # full walkthrough with expected outputs
    ├── run-demo.sh             # setup script + prompt list
    ├── sample-staged-diff.md   # captured diff that triggers curator refusal
    └── pyorders/               # the deliberately flawed FastAPI demo project
        ├── README.md
        ├── requirements.txt
        ├── src/
        └── tests/
```

See [`CHANGELOG.md`](CHANGELOG.md) for release history and attribution of each fix.

## Contributing

Open an issue describing a real situation where one of the agents missed, over-fired, or gave a bad recommendation. Include the diff or the prompt that produced it. PRs welcome on the subagent markdown itself.

## License

Apache License 2.0. See `LICENSE`.
