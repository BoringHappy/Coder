#!/usr/bin/env python3
import shutil
from pathlib import Path


def main():
    skills_src = Path("/usr/local/share/skills")
    skills_dest = Path("/home/agent/.claude/skills")

    if not skills_src.exists():
        return

    print("Setting up skills...")

    # Remove existing skills directory if it exists
    if skills_dest.exists():
        print(f"Removing existing skills directory: {skills_dest}")
        shutil.rmtree(skills_dest)

    # Copy the entire skills directory
    print(f"Copying skills from {skills_src} to {skills_dest}")
    shutil.copytree(skills_src, skills_dest)

    print("Setting up skills Done...")


if __name__ == "__main__":
    main()
