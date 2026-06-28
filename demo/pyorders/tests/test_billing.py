"""Tests for billing.apply_discount.

The first test passes. The second one fails because the production code
applies the discount to total (subtotal + tax) instead of subtotal only.
"""
from src.billing import apply_discount


def test_apply_discount_zero_percent():
    # Zero discount returns the full amount, regardless of how it is computed.
    result = apply_discount(subtotal=100.0, tax=10.0, discount_pct=0.0)
    assert result == 110.0


def test_apply_discount_ten_percent_applied_to_subtotal_only():
    # Subtotal $100, 10% discount => $90. Plus $10 tax => $100 total.
    # This is the contract the finance team requires for reconciliation.
    result = apply_discount(subtotal=100.0, tax=10.0, discount_pct=10.0)
    assert result == 100.0
