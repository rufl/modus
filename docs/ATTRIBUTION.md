# Licensing and Provenance Inventory

> **Documentation status: maintained reference.** This is a repository-local provenance audit, not legal advice. A retained license clears only the named material; `review_required` ledger rows remain distribution blockers.

**Updated:** September 9, 2026; retained third-party audit from August 2
**Machine-readable inventory:** [PROVENANCE_LEDGER.csv](PROVENANCE_LEDGER.csv)

## Current Ledger Boundary

`tools/generate_provenance_ledger.py` inventories the asset/resource extensions distributed from `game/`, `shared/`, `standalone/`, and `mods/`, plus the derived blood-pool script. The current ledger contains **230 assets: 18 cleared, 12 identified but requiring rights evidence, and 200 unverified**.

Run `tools/generate_provenance_ledger.py --check` after asset changes. `--strict` intentionally fails until every distributed row is cleared or removed.

## Confirmed Local License Material

| Material | Local evidence | Boundary |
| --- | --- | --- |
| LichForge project code and documentation | Root `LICENSE` and `docs/LICENSE`, SHA-256 `fc8f041b2c790ccc515a05f3418a6ddf57b9fd05f0eae9278eeef1c2307cd50b` | Applies only to material LichForge is entitled to license. |
| GUT test framework | `addons/gut/LICENSE.md` contains the MIT License and Tom “Butch” Wesley notice | Preserve with redistributed GUT source. |
| Main-menu warrior artwork | `game/art/ui/main_menu_warrior_lineup.png`, SHA-256 `361c74c50546ecdcf97b76c706ab7b1f805c0ede9feba6321754664c6e30128f` | User-directed generated artwork from the local OpenAI Codex image workflow on August 1, 2026; treated as project-owned. |
| Kenney Prototype Textures | Three retained PNGs under `game/art/textures/kenney_prototype_textures/` | Pixel-identical to their corresponding files in Kenney's official Prototype Textures ZIP. The official page states CC0; legal text is retained at `docs/licenses/KENNEY_CC0-1.0.txt`. |
| Kenney Particle Pack | Two retained PNGs under `game/art/textures/kenney_particle_pack/` | Pixel-identical to the official transparent PNGs. The official page states CC0; the same local CC0 text applies. |
| Blood-pool implementation | `shared/shaders/blood_pool.gd` and `game/art/shaders/blood_pool.gdshader` | Reviewed against dip000's `BloodyPool` source at commit `7a3e9bc685255d37f489e25b509fb56e185aa9fb`. Upstream is MIT; the notice is retained at `docs/licenses/DIP000_BLOODY_POOL_MIT.txt`. |
| Ten sample-item SVG icons | Original editable geometry under `game/art/ui/icons/`, authored with OpenAI assistance on September 9; each source embeds authorship and `SPDX-License-Identifier: MIT`, with hashes pinned by the ledger generator | Covers health, shield, speed/damage stims, materials, and ammunition icons only; no external artwork, fonts, or embedded images used. |

The Kenney files are pixel-equivalent rather than byte-identical because their PNG encoding differs from the current official ZIP. Their repository hashes and source URLs are pinned in the ledger.

## Identified but Not Cleared

| Material | Evidence | Required action |
| --- | --- | --- |
| Twelve music tracks under `game/art/audio/music/` | Embedded metadata names `rafael_dina`, says “made with suno,” and includes a unique creation ID for every track | Retain the applicable Suno account/plan commercial-use grant and generation records, or replace the tracks. Metadata identifies origin but is not a redistribution license. |
| Animation library and extracted `.res` clips | `AnimationLibrary_Godot.glb` contains the full animation set, but its glTF metadata identifies only Blender's exporter | Establish the animation source and license or replace the library and derived clips. |
| Mannequin/pistol/procedural models | glTF metadata identifies only the exporting application | Establish authorship/source/license or replace. |
| Remaining textures, decals, weapon icons, shaders, materials, and resources | Present in the generated ledger with hashes | Promote each row only after author, canonical source, license, and required notice are retained. |

## Historical Jeh3no Attribution

The current repository snapshot and its only retained base commit contain no `Jeh3no` source marker, bundled upstream license, or identifiable current dependency. It is therefore not represented as a distributed dependency in the ledger. If older history or an upstream import is recovered, re-open this review before release rather than inferring clearance from the old attribution alone.

## Export Notice Boundary

All export presets use `all_resources`. They must also include the root project license, this inventory, the generated ledger, and `docs/licenses/*.txt` as non-resource notice files. A packaged-build inspection is still required to prove those files are present in actual release artifacts.

## Release Rule

Do not ship or describe distribution clearance as approved while any ledger row is `review_required` or `identified_review_required`. Resolve unknown material by retaining proof, excluding it from export, or replacing it; then run:

```bash
tools/generate_provenance_ledger.py --check
tools/generate_provenance_ledger.py --strict
```
