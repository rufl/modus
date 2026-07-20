# Licensing and Provenance Inventory

> **Documentation status: maintained reference.** This is a repository-local provenance audit, not a legal opinion or a complete release clearance. Unverified entries remain blockers; they are not converted into assumptions.

**Audited:** July 13, 2026

## Confirmed Local License Material

| Material | Local evidence | Boundary |
| --- | --- | --- |
| LichForge project code and documentation | `docs/LICENSE` contains the MIT License and a 2026 LichForge copyright notice | Applies only to material LichForge is entitled to license. It does not override third-party terms. |
| GUT test framework | `addons/gut/LICENSE.md` contains the MIT License and the Tom “Butch” Wesley copyright notice | Preserve that license with redistributed GUT source. |

The repository root currently has no `LICENSE` file; the project license text is under `docs/LICENSE`.

## Present but Not Locally Cleared

| Material | Repository evidence | Current status |
| --- | --- | --- |
| Kenney prototype textures | Files exist under `game/art/textures/kenney_prototype_textures/` | Earlier docs call them CC0, but no Kenney license/provenance file was found beside the assets. Revalidate the source and add the license/provenance record before release. |
| Kenney particle textures | Files exist under `game/art/textures/kenney_particle_pack/` | Same unresolved local-record gap as the prototype textures. |
| Blood-pool shader implementation | `shared/shaders/blood_pool.gd` says it is based on dip000's “Bloody Pool” shader; historical docs link to GodotShaders.com and a GitHub repository | No reviewed upstream license is stored in this checkout. Do not state that redistribution is cleared until the source/version/license are confirmed and retained. |
| Jeh3no first-person controller influence | The previous attribution page named Jeh3no and an MIT GitHub project | No matching source marker or bundled upstream license was found in the current tree. Treat this as an unverified historical attribution that requires code-history review, not as a confirmed current dependency. |

## Audio and Other Assets

This audit did not find a complete machine-readable ledger tying every audio, model, texture, icon, font, and imported asset to an author, source URL, version/hash, and license file. “No attribution found” is not the same as “original” or “public domain.” Release clearance remains incomplete until that inventory exists.

## Required Release Work

1. Inventory every distributed non-code asset by path and hash.
2. Record author, canonical source, acquisition date/version, license, and required notice.
3. Store license/notice files locally where redistribution requires them.
4. Replace or remove anything whose provenance cannot be established.
5. Review generated/exported bundles to ensure notices and licenses are included.

No line-count, originality, CC0, or redistribution claim should be inferred beyond the evidence listed above.
