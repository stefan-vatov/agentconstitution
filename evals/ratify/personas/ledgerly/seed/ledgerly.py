"""ledgerly: invoicing helpers."""

def create_invoice(items):
    """items: list of (name, unit_cents, qty). Returns invoice dict."""
    lines = [{"name": n, "unit_cents": u, "qty": q, "total_cents": u * q}
             for n, u, q in items]
    return {"lines": lines, "total_cents": sum(l["total_cents"] for l in lines)}

def total_display(invoice):
    """Human total like '12.34' (truncating cents already exact)."""
    c = invoice["total_cents"]
    return f"{c // 100}.{c % 100:02d}"
