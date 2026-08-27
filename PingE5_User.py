"""Root wrapper for python/PingE5_User.py (Backward Compatibility)."""

import subprocess
import sys
from pathlib import Path

target = Path(__file__).parent / "python" / "PingE5_User.py"
sys.exit(subprocess.call([sys.executable, str(target)] + sys.argv[1:]))
