"""Checks relative links and #anchors in README.md and docs/ (not specs/plans).

Run from the repo root: python tests/check_links.py. Exit code = number of bad links.
"""
import glob
import os
import re
import sys


def slug(heading):
    """GitHub's anchor for a heading: lower case, punctuation dropped, spaces to -."""
    heading = heading.strip().lower()
    heading = re.sub(r"[^\w\- ]", "", heading)
    return heading.replace(" ", "-")


def without_code(text):
    return re.sub(r"```.*?```", "", text, flags=re.S)


def docs_files():
    files = ["README.md"]
    for path in glob.glob(os.path.join("docs", "**", "*.md"), recursive=True):
        parts = os.path.normpath(path).split(os.sep)
        if "specs" not in parts and "plans" not in parts:
            files.append(path)
    return files


def main():
    files = docs_files()
    anchors = {}
    for path in files:
        text = without_code(open(path, encoding="utf-8").read())
        anchors[os.path.normpath(path)] = {slug(h) for h in re.findall(r"^#+\s+(.*)$", text, re.M)}
    bad = 0
    for path in files:
        text = without_code(open(path, encoding="utf-8").read())
        for link in re.findall(r"\]\(([^)\s]+)\)", text):
            if link.startswith(("http://", "https://")):
                continue
            target_path, _, anchor = link.partition("#")
            target = os.path.normpath(os.path.join(os.path.dirname(path), target_path)) if target_path else os.path.normpath(path)
            if target_path and not os.path.exists(target):
                print(f"{path}: missing file {link}")
                bad += 1
            elif anchor and target.endswith(".md") and anchor not in anchors.get(target, set()):
                print(f"{path}: missing anchor {link}")
                bad += 1
    print(f"links: {bad} bad")
    return bad


if __name__ == "__main__":
    sys.exit(main())
