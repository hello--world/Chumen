#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "generate_icon.swift"


def main() -> None:
    env = os.environ.copy()
    env.setdefault("CLANG_MODULE_CACHE_PATH", "/private/tmp/chumen-clang-module-cache")
    subprocess.run(["swift", str(SCRIPT)], check=True, env=env)


if __name__ == "__main__":
    main()
