#!/usr/bin/env python3
"""Only genuinely integrated product source and tests can clear this gate."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
required = [
    "src/CartoRig",  # real runtime/node/adapter implementation, not a dummy file
    "tests/integration",  # real integration suite exercising actual components
    "packaging/build-windows.ps1",
]
missing = [name for name in required if not (root / name).exists()]
if missing:
    print("BLOCKED: no executable real-source integration harness; missing " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
print("Integration source is present. Running real integration suite is mandatory.")
# No implicit success: replace this gate only with real tests and observed outcomes.
print("BLOCKED: real integrated tests and coverage have not yet been implemented", file=sys.stderr)
sys.exit(1)
