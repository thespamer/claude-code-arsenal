# pyorders — demo project for claude-code-arsenal

A deliberately flawed order service used to exercise the six subagents.
Do not use in production. Do not copy patterns from here.

## What is here on purpose

This codebase is seeded with one or more issues per agent. The list:

| Issue | File | Caught by |
|---|---|---|
| SQL injection via f-string | `src/app.py:21,30,41` and `src/db.py:14,20` | security-auditor |
| Hardcoded JWT secret | `src/auth.py:5` | security-auditor |
| Hardcoded payment API key | `src/auth.py:8` | security-auditor |
| JWT signature verification disabled | `src/auth.py:14` | security-auditor |
| Admin route with no auth | `src/app.py:27` | security-auditor |
| DB credentials in source | `src/app.py:13`, `src/db.py:4` | security-auditor |
| Web handler talking directly to DB | `src/app.py` | architect |
| Domain and adapter mixed in one module | `src/billing.py` | architect |
| Config duplicated across modules | `src/db.py:4` vs `src/app.py:13` | architect |
| N+1 query on items | `src/db.py:11-23` | cost-sentinel |
| N+1 external paid API calls | `src/billing.py:14-25` | cost-sentinel |
| `SELECT *` with no `LIMIT` | `src/app.py:30` | cost-sentinel |
| Real bug in `apply_discount` | `src/billing.py:33-37` | test-fixer (test catches it) |
| `requests==2.18.0` (CVE-2018-18074) | `requirements.txt` | dependency-detective |
| `pyyaml==3.13` (CVE-2017-18342) | `requirements.txt` | dependency-detective |
| `django==1.11.29` (EOL) | `requirements.txt` | dependency-detective |
| `flask` redundant with `fastapi` | `requirements.txt` | dependency-detective |
| `numpy` declared but unused | `requirements.txt` | dependency-detective |
| Mixed-purpose staged area | `demo/sample-staged-diff.md` | commit-curator |

## Running

```bash
# From the repository root
./demo/run-demo.sh setup

# Then start Claude Code inside the demo dir
cd demo/pyorders
claude
```

See `../DEMO.md` for the full walkthrough.

## Why FastAPI

Smallest realistic web service stack in Python. Same patterns and issues
apply to Flask, Express, Spring, Rails. The agents do not depend on the
framework.
