"""Billing logic. Intentionally flawed for demo purposes."""
import requests

from src.auth import PAYMENT_API_KEY
from src.db import get_orders_with_items

PAYMENT_API = "https://api.payment-provider.example/v1/charge"


def process_pending_payments(user_id: int):
    """Charge every pending order for a user.

    Demo issue: N+1 against an external paid API. One HTTP call per order, no batching.
    """
    orders = get_orders_with_items(user_id)
    results = []
    for entry in orders:
        order = entry["order"]
        order_id = order[0]
        total = order[2]
        # Per-order API call. At 1000 orders, this is 1000 paid API calls.
        response = requests.post(
            PAYMENT_API,
            json={"amount": total, "currency": "USD", "order_id": order_id},
            headers={"Authorization": f"Bearer {PAYMENT_API_KEY}"},
        )
        results.append(response.json())
    return results


def apply_discount(subtotal: float, tax: float, discount_pct: float) -> float:
    """Apply a percentage discount and return the final amount.

    Demo issue: real bug. Discount must be applied to the subtotal only,
    then tax added on top. Current implementation discounts the tax as well,
    which understates the tax owed and breaks reconciliation.
    """
    return subtotal * (1 - discount_pct / 100) + tax
