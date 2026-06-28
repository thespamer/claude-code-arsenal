# claude-code-arsenal

Six specialized Claude Code subagents for daily engineering work. Each one is read-only by default unless the job requires write access, and each one has a sharp scope so the main session can delegate without losing context.

## The six

| Agent | Job | Tools | Model | Read/Write |
|---|---|---|---|---|
| `architect` | Map the codebase, surface boundary violations, propose ADRs | Read, Grep, Glob | sonnet | Read-only |
| `security-auditor` | Sweep for secrets, IAM, OWASP patterns, vulnerable deps | Read, Grep, Glob, Bash | sonnet | Read-only |
| `cost-sentinel` | Flag patterns that become expensive at production scale | Read, Grep, Glob | sonnet | Read-only |
| `test-fixer` | Diagnose and repair failing tests with the minimal change | Read, Edit, Bash, Grep, Glob | sonnet | Read-write |
| `dependency-detective` | Audit dependencies for vulns, staleness, redundancy, licenses | Read, Grep, Glob, Bash | sonnet | Read-only |
| `commit-curator` | Draft a Conventional Commits message from staged changes | Read, Bash | haiku | Read-only |

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

- **Read-only by default.** Four of six cannot write to the filesystem. They report findings; humans take action.
- **One agent, one job.** No agent crosses categories. If a job needs three perspectives, run three agents.
- **Minimal blast radius.** `test-fixer` is the only one that edits code, and it refuses to touch more than three files.
- **No fabricated findings.** Every output points at a file and a line. CVE numbers, version numbers, and dollar figures come from real tools or are flagged as estimates with stated assumptions.
- **Honest stop conditions.** If the codebase is too small, the diff is empty, or the change is too large, the agent stops instead of guessing.

## Repository layout

```
claude-code-arsenal/
├── README.md
├── LICENSE
├── PUBLISH.md
├── agents/
│   ├── architect.md
│   ├── commit-curator.md
│   ├── cost-sentinel.md
│   ├── dependency-detective.md
│   ├── security-auditor.md
│   └── test-fixer.md
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

## Contributing

Open an issue describing a real situation where one of the agents missed, over-fired, or gave a bad recommendation. Include the diff or the prompt that produced it. PRs welcome on the subagent markdown itself.

## License

Apache License 2.0. See `LICENSE`.
