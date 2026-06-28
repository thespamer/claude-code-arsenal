## Sample staged diff for demoing `commit-curator`

This is a captured `git diff --cached` output containing two unrelated changes
in one staging area. The curator should refuse to author a single commit and
recommend splitting them.

```diff
diff --git a/src/billing.py b/src/billing.py
index 1234567..89abcde 100644
--- a/src/billing.py
+++ b/src/billing.py
@@ -28,7 +28,7 @@ def apply_discount(subtotal: float, tax: float, discount_pct: float) -> float:
     which understates the tax owed and breaks reconciliation.
     """
-    total = subtotal + tax
-    return total * (1 - discount_pct / 100)
+    discounted_subtotal = subtotal * (1 - discount_pct / 100)
+    return discounted_subtotal + tax


diff --git a/README.md b/README.md
index aaaaaaa..bbbbbbb 100644
--- a/README.md
+++ b/README.md
@@ -1,3 +1,7 @@
 # Pyorders

 A small order service.
+
+## Running locally
+
+`uvicorn src.app:app --reload`
```

To reproduce the demo:

```bash
cd demo/pyorders
git init
git add src/billing.py README.md
# Then in Claude Code:
#   > use the commit-curator on my staged changes
```
