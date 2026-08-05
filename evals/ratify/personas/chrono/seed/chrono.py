"""chrono: date parsing helpers."""
import re
from datetime import date

_ISO = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")

def parse_date(text):
    """Parse YYYY-MM-DD into datetime.date; raise ValueError otherwise."""
    m = _ISO.match(text.strip())
    if not m:
        raise ValueError(f"unparseable date: {text!r}")
    return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
