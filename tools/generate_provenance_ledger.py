#!/usr/bin/env python3
"""Generate MODUS's deterministic distribution-asset provenance ledger."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/PROVENANCE_LEDGER.csv"
SCAN_ROOTS = ("game", "shared", "standalone", "mods")
ASSET_SUFFIXES = {
    ".flac",
    ".fbx",
    ".gdshader",
    ".glb",
    ".gltf",
    ".jpeg",
    ".jpg",
    ".mp3",
    ".obj",
    ".ogg",
    ".otf",
    ".png",
    ".res",
    ".svg",
    ".tres",
    ".ttf",
    ".wav",
    ".webp",
}
EXTRA_PATHS = ("shared/shaders/blood_pool.gd",)

KENNEY = {
    "game/art/textures/kenney_particle_pack/circle_05.png":
        "616c989de83cd805c80ed78f692c5a4cb754151edbb1d3550f20cc3a2857b706",
    "game/art/textures/kenney_particle_pack/star_05.png":
        "9113f3620bf54a4afc8560ed006e67363850aceb46bcac059f5199e43407cd3b",
    "game/art/textures/kenney_prototype_textures/dark/texture_09.png":
        "46e1233f862fb4da9e7ab6821bb5614f5574bfc39d3199606628b91f05f82e1d",
    "game/art/textures/kenney_prototype_textures/orange/texture_07.png":
        "e6f01b5ae1b315e2ae6dbe9c2ee3c22053479ecb4bed90910f1142d0563b8d83",
    "game/art/textures/kenney_prototype_textures/orange/texture_09.png":
        "6fb33751454dcfeb0181041e2e70d438bd3847be1fc8c72123a9477d22dc5c34",
}
BLOOD_POOL_PATHS = {
    "game/art/shaders/blood_pool.gdshader",
    "shared/shaders/blood_pool.gd",
}
HERO_PATH = "game/art/ui/main_menu_warrior_lineup.png"
SUNO_ID = re.compile(rb"id=([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})")

FIELDNAMES = (
    "path",
    "sha256",
    "bytes",
    "kind",
    "status",
    "author",
    "source",
    "license",
    "local_notice",
    "notes",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_paths() -> list[Path]:
    paths: set[Path] = set()
    for root_name in SCAN_ROOTS:
        root = ROOT / root_name
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in ASSET_SUFFIXES:
                paths.add(path)
    for relative in EXTRA_PATHS:
        path = ROOT / relative
        if path.is_file():
            paths.add(path)
    return sorted(paths, key=lambda path: path.relative_to(ROOT).as_posix())


def classify(path: Path, digest: str) -> dict[str, str]:
    relative = path.relative_to(ROOT).as_posix()
    base = {
        "status": "review_required",
        "author": "unverified",
        "source": "unverified",
        "license": "unverified",
        "local_notice": "",
        "notes": "No repository-local provenance record currently clears this distributed asset.",
    }

    if relative in KENNEY:
        if digest != KENNEY[relative]:
            base["notes"] = "File hash changed after the official-pack pixel-equivalence review."
            return base
        pack = "Particle Pack" if "particle_pack" in relative else "Prototype Textures"
        slug = "particle-pack" if pack == "Particle Pack" else "prototype-textures"
        return {
            "status": "cleared",
            "author": "Kenney",
            "source": f"https://kenney.nl/assets/{slug}",
            "license": "CC0-1.0",
            "local_notice": "docs/licenses/KENNEY_CC0-1.0.txt",
            "notes": (
                f"Pixel-identical to the corresponding PNG in the official Kenney {pack} "
                "ZIP; PNG encoding differs."
            ),
        }

    if relative in BLOOD_POOL_PATHS:
        return {
            "status": "cleared",
            "author": "Adrián (dip000), modified by LichForge",
            "source": (
                "https://github.com/dip000/my-godotshaders/tree/"
                "7a3e9bc685255d37f489e25b509fb56e185aa9fb/BloodyPool"
            ),
            "license": "MIT",
            "local_notice": "docs/licenses/DIP000_BLOODY_POOL_MIT.txt",
            "notes": (
                "Derived implementation reviewed against the pinned upstream BloodyPool source."
            ),
        }

    if relative == HERO_PATH:
        return {
            "status": "cleared",
            "author": "LichForge / user-directed generated artwork",
            "source": "Local OpenAI Codex image workflow, 2026-08-01",
            "license": "Project-owned",
            "local_notice": "LICENSE",
            "notes": (
                "Generation provenance is retained in docs/ATTRIBUTION.md and release evidence."
            ),
        }

    if relative.startswith("game/art/audio/music/") and path.suffix.lower() == ".mp3":
        match = SUNO_ID.search(path.read_bytes())
        source = "Embedded metadata: made with Suno"
        if match:
            source += "; asset id " + match.group(1).decode("ascii")
        return {
            "status": "identified_review_required",
            "author": "rafael_dina (embedded metadata)",
            "source": source,
            "license": "commercial-use grant not retained locally",
            "local_notice": "",
            "notes": (
                "Retain account/plan-generation rights evidence or replace before distribution."
            ),
        }

    return base


def build_csv() -> tuple[str, dict[str, int]]:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=FIELDNAMES, lineterminator="\n")
    writer.writeheader()
    counts: dict[str, int] = {}

    for path in asset_paths():
        relative = path.relative_to(ROOT).as_posix()
        digest = sha256(path)
        classification = classify(path, digest)
        status = classification["status"]
        counts[status] = counts.get(status, 0) + 1
        writer.writerow(
            {
                "path": relative,
                "sha256": digest,
                "bytes": path.stat().st_size,
                "kind": path.suffix.lower().lstrip(".") or "file",
                **classification,
            }
        )

    return output.getvalue(), counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if the ledger is stale")
    parser.add_argument("--strict", action="store_true", help="fail if any asset is not cleared")
    args = parser.parse_args()

    content, counts = build_csv()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != content:
            print("Provenance ledger is stale; run tools/generate_provenance_ledger.py")
            return 1
    else:
        OUTPUT.write_text(content, encoding="utf-8")

    total = sum(counts.values())
    summary = ", ".join(f"{key}={counts[key]}" for key in sorted(counts))
    print(f"Provenance ledger: {total} assets ({summary})")
    if args.strict and counts.get("review_required", 0) + counts.get(
        "identified_review_required", 0
    ):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
