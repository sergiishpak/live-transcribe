#!/usr/bin/env python3
"""Read the release version, or bump it and release the Unreleased changelog."""

import argparse
from datetime import date
from pathlib import Path
import re


def parse_version(value):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", value):
        raise ValueError("VERSION must be MAJOR.MINOR.PATCH without leading zeroes (for example, 0.1.1).")
    return tuple(map(int, value.split(".")))


def next_version(value, increment):
    parts = list(parse_version(value))
    index = ("major", "minor", "patch").index(increment)
    parts[index] += 1
    parts[index + 1:] = [0] * (2 - index)
    return ".".join(map(str, parts))


def release_changelog(text, version, released_on):
    heading = re.search(r"(?m)^## \[Unreleased\][ \t]*$", text)
    if not heading:
        raise ValueError("CHANGELOG.md needs a ## [Unreleased] section.")
    if re.search(rf"(?m)^## \[{re.escape(version)}\](?:[ \t]|$)", text):
        raise ValueError(f"CHANGELOG.md already contains {version}.")
    remaining = text[heading.end():]
    next_heading = re.search(r"(?m)^## ", remaining)
    notes = remaining[:next_heading.start()] if next_heading else remaining
    history = remaining[next_heading.start():] if next_heading else ""
    if not notes.strip():
        raise ValueError("Add release notes under ## [Unreleased] before bumping the version.")
    return (
        text[:heading.end()]
        + f"\n\n## [{version}] - {released_on}\n\n"
        + notes.strip() + "\n\n" + history
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("increment", nargs="?", choices=("major", "minor", "patch"))
    parser.add_argument("--dry-run", action="store_true", help="Preview a bump without writing files")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        current = (root / "VERSION").read_text().strip()
        parse_version(current)
        if not args.increment:
            print(current)
            return
        updated = next_version(current, args.increment)
        changelog_path = root / "CHANGELOG.md"
        changelog = release_changelog(changelog_path.read_text(), updated, date.today().isoformat())
        if not args.dry_run:
            changelog_path.write_text(changelog)
            (root / "VERSION").write_text(updated + "\n")
        print(f"{current} -> {updated}" + (" (dry run)" if args.dry_run else ""))
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
