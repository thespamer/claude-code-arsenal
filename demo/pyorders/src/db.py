"""Database access. Intentionally flawed for demo purposes."""
import psycopg2

DB_URL = "postgresql://admin:password123@localhost:5432/orders"


def get_orders_with_items(user_id: int):
    """Return all orders for a user, with their line items.

    Demo issue: classic N+1. One query for orders, then one per order for items.
    """
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    cur.execute(f"SELECT * FROM orders WHERE user_id = {user_id}")
    orders = cur.fetchall()

    result = []
    for order in orders:
        order_id = order[0]
        cur.execute(f"SELECT * FROM items WHERE order_id = {order_id}")
        items = cur.fetchall()
        result.append({"order": order, "items": items})

    conn.close()
    return result
