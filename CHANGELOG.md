# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-06

Post-validation release. Every fix in this version was surfaced by running the arsenal against its own codebase or by external review of the v1.0 release.

### Added

- **`agents/AGENT-CONVENTIONS.md`.** Shared guardrails (no fabricated findings, manifest as source of truth, honest stop conditions, delegation over cross-domain analysis) that all six agents inherit. Each agent file now references this document instead of restating rules.
- **`tools/verify-manifest.sh`.** A consistency check that derives each agent's actual permissions (FS writes, shell exec, network) from its `tools:` YAML frontmatter and compares them to what the README table claims. Fails with a specific diff on drift.
- **GitHub Actions workflow (`.github/workflows/verify-manifest.yml`).** Runs `verify-manifest.sh` on every push to `main` and every PR touching `agents/`, `README.md`, or the script itself.

### Changed

- **README permission table.** Replaced the ambiguous "Read-only" / "Read-write" labels with three explicit boolean columns: **FS writes**, **Shell exec**, **Network**. Each column maps 1:1 to the presence of specific tools (`Write`/`Edit`, `Bash`, `WebFetch`/`WebSearch`) in the agent's frontmatter, so the label matches enforcement instead of hiding it.
- **README design principles section.** Replaced "Read-only by default" (which was misleading — Bash access is not read-only in any operational sense) with "Manifest is the source of truth", explicitly calling out that the `tools:` frontmatter is the enforceable ground truth and that CI enforces README ↔ manifest consistency.
- **`agents/security-auditor.md`.** Removed Pass 5 (dependency CVE scanning via `pip-audit`/`npm audit`/`cargo audit`). This work overlapped with `dependency-detective`, producing duplicate findings across two agents. The auditor now delegates via an "Out of scope" section.
- **`agents/dependency-detective.md`.** Rewrote the redundancy detection to fire independently from the unused check. A package can be redundant even when unused, and the two facts warrant separate reporting because the *reason* to remove and the migration path differ. Also expanded the category list (frameworks, ORMs, HTTP clients, date libraries, test runners, state, logging).
- **`agents/commit-curator.md`.** Added Step 0 that resolves the repo root via `git rev-parse --show-toplevel` before running any git command, preventing nested-repo confusion. Explicitly forbids reading `git log`, `git diff HEAD`, or `git show HEAD` when describing the current commit candidate — history is context, not state.
- **`PUBLISH.md`.** Removed all hardcoded references to a specific GitHub username. Now resolves the current user via `GH_USER=$(gh api user --jq .login)` so forks and re-publishes work without any manual edit.

### Fixed

- Documentation label for `security-auditor` and `commit-curator` (previously called "Read-only" despite having `Bash` in their `tools:` list). The new taxonomy correctly identifies them as shell-capable-but-filesystem-read-only.

### Attribution

The findings that drove this release:

1. **CVE scanning overlap between `security-auditor` and `dependency-detective`** — surfaced by the `architect` agent when run against the arsenal repo itself.
2. **Misleading "Read-only" label for `commit-curator`** — surfaced by the `architect` agent, and independently raised in external review after the v1.0 announcement.
3. **Duplicated guardrails across six agent files** — surfaced by the `architect` agent, addressed via `AGENT-CONVENTIONS.md`.
4. **Hardcoded username in `PUBLISH.md`** — surfaced by the `architect` agent.
5. **Redundancy detection short-circuited by unused check** — surfaced during the `dependency-detective` demo run (flask + fastapi flagged as unused, not as redundant).
6. **Nested-repo scope confusion in `commit-curator`** — surfaced during the commit-curator Flow B demo run.
7. **README permission taxonomy not enforceable against `tools:` frontmatter** — surfaced in external review, drove the `verify-manifest.sh` + CI workflow additions.

## [1.0.0] — 2026-06

Initial release.

### Added

- Six specialized Claude Code subagents: `architect`, `security-auditor`, `cost-sentinel`, `test-fixer`, `dependency-detective`, `commit-curator`.
- Working demo project (`demo/pyorders/`) seeded with one or more issues per agent.
- End-to-end walkthrough (`demo/DEMO.md`) with real run output, timings, and screenshots for each agent.
- Setup script (`demo/run-demo.sh`) that installs agents, sets up a venv with required dependencies, initializes git, and validates the seeded failing test.
- Apache 2.0 license.
