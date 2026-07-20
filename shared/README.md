# Shared Runtime Libraries

> **Documentation status: maintained reference.** This page describes the directories that currently exist under `shared/`.

| Path | Current contents |
| --- | --- |
| `shared/editor_core/` | Editor actors, core data, gizmos, nodes, scripts, tools, textures, and UI support |
| `shared/ui_core/` | Shared UI components, managers, and screens, including the configured main menu |
| `shared/shaders/` | Blood-pool shader code, helpers, scenes, and subsystem documentation |

These directories are shared by multiple repository surfaces, but cross-context compatibility must be verified per caller. The standalone editor is not currently proven as a complete exported product, and shader demo scenes are not production performance evidence.

Do not rely on the retired `shared/editor/`, `shared/data/`, or `shared/utils/` layout described by older snapshots.
