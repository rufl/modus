#!/usr/bin/env python3
"""Compare notices in a real Godot ZIP export with their repository originals."""

import argparse
import csv
from pathlib import Path
from zipfile import ZipFile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    required = {
        "LICENSE",
        "docs/LICENSE",
        "docs/ATTRIBUTION.md",
        "docs/PROVENANCE_LEDGER.csv",
    }
    with (root / "docs/PROVENANCE_LEDGER.csv").open(newline="", encoding="utf-8") as stream:
        required.update(row["local_notice"] for row in csv.DictReader(stream) if row["local_notice"])

    failures = []
    with ZipFile(args.archive) as package:
        names = set(package.namelist())
        if any(name.startswith("addons/gut/") for name in names):
            required.add("addons/gut/LICENSE.md")
        for path in sorted(required):
            if path not in names:
                failures.append(f"Missing exported notice: {path}")
            elif package.read(path) != (root / path).read_bytes():
                failures.append(f"Exported notice differs from repository: {path}")
        for path in sorted(names):
            if path.startswith("docs/PROVENANCE_LEDGER.") and path.endswith(".translation"):
                failures.append(f"Provenance data incorrectly exported as a translation: {path}")
            if path.startswith("logs/"):
                failures.append(f"Local development log exported: {path}")

    for failure in failures:
        print(f"FAIL: {failure}")
    if failures:
        return 1
    print(f"PASS: {len(required)} exported notices match; no ledger translations or local logs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
