#!/usr/bin/env python3
"""Format code files after Edit/Write operations using appropriate formatters."""
import json
import subprocess
import sys
from pathlib import Path


def main():
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if not file_path:
        return

    path = Path(file_path)
    if not path.exists():
        return

    suffix = path.suffix.lower()

    formatters = {
        ".py": ["ruff", "format", "--quiet"],
        ".json": ["jq", ".", "-M"],
    }

    if suffix not in formatters:
        return

    cmd = formatters[suffix]

    try:
        if suffix == ".json":
            result = subprocess.run(cmd + [str(path)], capture_output=True, text=True)
            if result.returncode == 0 and result.stdout:
                path.write_text(result.stdout)
        else:
            subprocess.run(cmd + [str(path)], capture_output=True)
    except FileNotFoundError:
        pass


if __name__ == "__main__":
    main()
