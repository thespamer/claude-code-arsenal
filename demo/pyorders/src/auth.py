"""Authentication helpers. Intentionally flawed for demo purposes."""
import jwt

# Hardcoded JWT secret in source code.
JWT_SECRET = "supersecret123"

# Hardcoded payment provider API key.
PAYMENT_API_KEY = "Your_token_from_istripe_HERE"


def verify_token(token: str) -> bool:
    try:
        # Signature verification disabled. Token is trusted blindly.
        jwt.decode(token, options={"verify_signature": False})
        return True
    except Exception:
        return False


def issue_token(user_id: str) -> str:
    return jwt.encode({"sub": user_id}, JWT_SECRET, algorithm="HS256")
# trailing comment
