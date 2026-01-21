#!/usr/bin/env python3
import shutil
from pathlib import Path


def main():
    skills_src = Path("/usr/local/share/skills")
    skills_dest = Path("/home/agent/.claude/skills")

    if not skills_src.exists():
        return

    print("Setting up skills...")
    skills_dest.mkdir(parents=True, exist_ok=True)

    for src_file in skills_src.rglob("*"):
        if src_file.is_file():
            rel_path = src_file.relative_to(skills_src)
            dest_file = skills_dest / rel_path

            if not dest_file.exists():
                dest_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src_file, dest_file)
                print(f"Copied skill: {rel_path}")


if __name__ == "__main__":
    main()
