# Demo walkthrough — see all six agents in action

This walkthrough uses the small flawed FastAPI project under `demo/pyorders/`.
It is intentionally seeded with one or more issues per agent so you can run
each agent and see a real finding.

## Setup (one minute)

```bash
# From the root of claude-code-arsenal
mkdir -p ~/.claude/agents
cp agents/*.md ~/.claude/agents/

# Open Claude Code in the demo project
cd demo/pyorders
claude
```

Inside Claude Code, confirm the agents loaded:

```
/agents
```

You should see the six listed under Personal scope.

## The demo app in 30 seconds

```
demo/pyorders/
├── requirements.txt          # mix of vulnerable, stale, redundant, unused deps
├── src/
│   ├── app.py                # FastAPI handlers with layering issues + SQL injection
│   ├── auth.py               # hardcoded JWT secret, hardcoded API key, JWT not verified
│   ├── db.py                 # N+1 query pattern
│   └── billing.py            # N+1 external API + real discount bug
└── tests/
    └── test_billing.py       # one passing test, one failing test (catches the bug)
```

Total surface area: about 130 lines of Python. Small enough to read in two minutes, broken enough to give every agent something real to do.

---

## 1. architect

```
> use the architect to review the structure of this project
```

**What it finds:**

- `src/app.py` imports `psycopg2` and runs raw SQL directly from HTTP handlers. The web layer is talking to the database. There is no service layer, no repository, no domain model.
- `src/billing.py` mixes domain logic (`apply_discount`) with adapter concerns (HTTP calls to the payment provider). Two responsibilities in one module.
- `src/db.py` re-declares `DB_URL` instead of pulling from a single config source. Connection strings live in two files.
- No `__init__.py`-level public API. Internal modules are imported by absolute path from anywhere.

**Expected output shape:**

```
## Architectural findings

### Major
- src/app.py:21 — handlers execute SQL directly against psycopg2.
  Why it matters: every schema change ripples through the HTTP layer.
  Recommendation: extract a `repositories/` module; handlers call repositories, not the driver.

- src/billing.py — domain and adapter concerns in one file.
  Why it matters: testing `apply_discount` should not require mocking HTTP.
  Recommendation: split into `billing/domain.py` (pure) and `billing/payment_adapter.py` (HTTP).

### Minor
- src/db.py:4 and src/app.py:10 — DB_URL duplicated in two modules.
  Recommendation: single `src/config.py` reading from environment.

## Shape of the system
A FastAPI service for orders, currently written as four flat modules with
no layering. Web handlers reach directly into the database driver and into
a billing module that also speaks to a payment API. A new engineer would
read this as "a script with HTTP routes," not as a service.
```

---

## 2. security-auditor

```
> use the security-auditor to sweep this codebase
```

**What it finds:**

- `src/auth.py:5` — JWT_SECRET hardcoded.
- `src/auth.py:8` — payment API key hardcoded (`sk_live_...` prefix matches a common pattern).
- `src/auth.py:14` — `jwt.decode(..., options={"verify_signature": False})`. Tokens accepted without signature verification.
- `src/app.py:13` — `DB_URL` contains the password in source.
- `src/app.py:21, 30, 41` — SQL injection via f-string interpolation in three places.
- `src/app.py:27` — `/admin/all-orders` has no `Depends(verify_token)` or equivalent.
- `requirements.txt` — `requests==2.18.0` (CVE-2018-18074), `pyyaml==3.13` (CVE-2017-18342), `django==1.11.29` (multiple CVEs).

**Expected output shape:**

```
## Security findings

### CRITICAL
- src/app.py:21,30,41 (input handling) — SQL injection via f-string in three handlers.
  Risk: any client can read or modify arbitrary data in the orders database.
  Fix: use parameterized queries (psycopg2 supports `cur.execute(sql, params)`).

- src/auth.py:14 (authentication) — JWT signature verification disabled.
  Risk: forged tokens accepted; any user identity can be impersonated.
  Fix: `jwt.decode(token, JWT_SECRET, algorithms=["HS256"])` and remove the options dict.

- src/auth.py:5,8 (secrets) — JWT secret and payment API key hardcoded.
  Risk: anyone with repo read access has prod credentials.
  Fix: load from environment; rotate both keys immediately.

### HIGH
- src/app.py:27 (authorization) — admin route has no auth dependency.
- requirements.txt — three packages with known CVEs.

3 critical, 2 high, 0 medium, 0 low.
Blocking items: parameterized queries, JWT verification, secret rotation.
```

---

## 3. cost-sentinel

```
> use the cost-sentinel on this codebase
```

**What it finds:**

- `src/db.py:11-23` — N+1 query against the database. One query for orders, then one query per order for items.
- `src/billing.py:14-25` — N+1 against a paid external API. One `requests.post` per pending order, no batching.
- `src/app.py:30` — `SELECT * FROM orders` with no `LIMIT` and no pagination. At 1M rows this returns the whole table.
- `src/app.py:21,30,41` — `SELECT *` instead of named columns. Wide rows pulled across the wire.
- `src/billing.py:18` — no retry budget, no idempotency key on the payment call.

**Expected output shape:**

```
## Cost findings

### High impact (>$100/month at moderate scale)
- src/billing.py:14-25 — per-order call to the payment API inside a loop.
  Why expensive: provider charges per call; at 10K orders/day this is 300K paid calls/month.
  Estimated impact: $300-3000/month depending on per-call price.
  Mitigation: batch endpoint if the provider has one; otherwise enqueue and dedupe.

- src/app.py:30 — unbounded SELECT * on the orders table from an HTTP handler.
  Why expensive: full table scan + full row serialization on every admin page load.
  Mitigation: add LIMIT/OFFSET pagination, project the columns the UI actually uses.

### Medium impact
- src/db.py:11-23 — N+1 on items query.
  Mitigation: single JOIN, or `WHERE order_id = ANY(%s)` with the order ID list.

Top three interventions: batch payment calls, paginate admin queries, JOIN items.
```

---

## 4. test-fixer

First run the test suite to see the failure:

```bash
cd demo/pyorders
pip install pytest fastapi pyjwt
pytest tests/ -v
```

You will see `test_apply_discount_ten_percent_applied_to_subtotal_only` fail. Then:

```
> use the test-fixer on tests/test_billing.py::test_apply_discount_ten_percent_applied_to_subtotal_only
```

**What it finds:**

The test expects `100.0`. The function returns `99.0`. Test is correct (discount applies to subtotal only, per the docstring contract). The production code is wrong: it adds tax first, then discounts the total.

**Expected output shape:**

```
## Diagnosis
Bucket: Real bug in production code.
Root cause: apply_discount applies the discount percentage to (subtotal + tax)
instead of to subtotal alone.

## Fix
File: src/billing.py
Change: compute discounted subtotal first, then add tax on top.
Rationale: matches the contract in the docstring and the finance team's
reconciliation requirement.

## Verification
- tests/test_billing.py::test_apply_discount_ten_percent_applied_to_subtotal_only: PASS
- tests/test_billing.py: PASS (2/2)
```

The fix diff the agent applies will look like:

```diff
-    total = subtotal + tax
-    return total * (1 - discount_pct / 100)
+    discounted_subtotal = subtotal * (1 - discount_pct / 100)
+    return discounted_subtotal + tax
```

---

## 5. dependency-detective

```
> use the dependency-detective on requirements.txt
```

**What it finds:**

```bash
# the agent will run, when available:
pip-audit -r requirements.txt
```

- `requests==2.18.0` — CVE-2018-18074, fixed in 2.20.0.
- `pyyaml==3.13` — CVE-2017-18342, fixed in 5.1.
- `django==1.11.29` — EOL April 2020, multiple CVEs.
- `pyjwt==1.5.3` — two majors behind (current is 2.x).
- `flask==0.10.1` alongside `fastapi==0.68.0` — two web frameworks, pick one.
- `numpy==1.16.0` — declared but no `import numpy` in `src/`.

**Expected output shape:**

```
## Dependency audit

### Security (now)
- requests==2.18.0 — CVE-2018-18074, fixed in 2.20.0. Used by src/billing.py.
- pyyaml==3.13 — CVE-2017-18342, fixed in 5.1. No usage found, candidate for removal.
- django==1.11.29 — EOL, multiple CVEs. No usage found, candidate for removal.

### Stale
- pyjwt==1.5.3 → latest 2.x. Two majors behind. Breaking changes in 2.0.

### Redundant
- flask and fastapi both present. Used by: only fastapi imported in src/. Remove flask.

### Unused
- numpy in requirements, no imports in src/. Safe to remove.

Sequence: remove unused first (django, pyyaml, numpy, flask), then upgrade requests,
then plan pyjwt 2.x migration.
```

---

## 6. commit-curator

Set up a small staging area, then invoke. Two flows shown below.

### Flow A — clean single-purpose commit

```bash
cd demo/pyorders
git init && git add .
git commit -m "chore: initial demo skeleton"

# Now make one focused change:
# (apply the test-fixer's fix manually, or any small targeted edit)
git add src/billing.py
```

Then in Claude Code:

```
> use the commit-curator on my staged changes
```

**Expected output:**

```
fix(billing): apply discount to subtotal before adding tax

The previous implementation discounted the total including tax, which
understated the tax owed on every discounted order. Finance reconciliation
flagged the mismatch.

Run `git commit -F-` and paste the block above.
```

### Flow B — staged area with two unrelated changes (the curator should refuse)

```bash
git add src/billing.py README.md
```

(Where `src/billing.py` is the fix and `README.md` adds a "running locally" section.)

```
> use the commit-curator on my staged changes
```

**Expected output:**

```
This staging area contains two unrelated changes. Recommend splitting:

Commit 1 (fix):
  git reset && git add src/billing.py
  → fix(billing): apply discount to subtotal before adding tax

Commit 2 (docs):
  git add README.md
  → docs: add running-locally section

Run the curator again after each split.
```

See `demo/sample-staged-diff.md` for the captured diff that triggers Flow B.

---

## What "watching it work" looks like

If you want to capture this for sharing (LinkedIn, internal demo), the
flow that reads best is:

1. Open a terminal with `claude` running in `demo/pyorders/`.
2. Run each agent in the order above, one per screen.
3. After agents 1-3 (read-only audits), run `pytest tests/ -v` to show the
   real failing test, then run agent 4 to fix it.
4. End with agent 6 on a clean commit, then agent 6 again on a mixed
   stage to show the refusal.

The full sequence takes about 5 minutes. The signal is the cumulative
quality and specificity of the findings, not any one agent in isolation.
