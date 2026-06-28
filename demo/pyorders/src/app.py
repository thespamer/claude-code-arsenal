"""Pyorders order API. Intentionally flawed for demo purposes."""
from fastapi import FastAPI
import psycopg2

from src.auth import verify_token

app = FastAPI()

# Hardcoded connection string with credentials (security issue)
DB_URL = "postgresql://admin:password123@localhost:5432/orders"


@app.get("/orders/{order_id}")
def get_order(order_id: str):
    # Layering violation: web handler talks to the DB directly.
    # SQL injection: order_id interpolated into the query string.
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute(f"SELECT * FROM orders WHERE id = {order_id}")
    row = cur.fetchone()
    conn.close()
    return row


@app.get("/admin/all-orders")
def admin_all_orders():
    # No auth on an admin route.
    # SELECT * on a wide table, no LIMIT, unbounded result set.
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute("SELECT * FROM orders")
    rows = cur.fetchall()
    conn.close()
    return rows


@app.post("/orders")
def create_order(order: dict, token: str):
    if not verify_token(token):
        return {"error": "unauthorized"}
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute(
        f"INSERT INTO orders (user_id, total) VALUES ({order['user_id']}, {order['total']}) RETURNING id"
    )
    new_id = cur.fetchone()[0]
    conn.commit()
    conn.close()
    return {"id": new_id}
