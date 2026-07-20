# MODUS Standalone Editor

> **Documentation status: maintained reference.** A standalone scene and export preset exist, but the exported editor is not currently proven as a complete product.

## Current source

- Entry scene: `standalone/editor/main.tscn`
- Entry script: `standalone/editor/standalone_main.gd`
- Embedded editor reused by the entry: `game/editor/embedded_level_editor.gd`
- Export preset: `Standalone Editor` in `export_presets.cfg`
- Preset output: `standalone/editor/editor.exe`
- Custom feature: `standalone_editor`

## Implemented in the standalone entry

The script instantiates the embedded editor and creates File, Edit, View, and Help menus. It wires new/open/save/save-as actions to the embedded editor and exposes basic view toggles/about text.

## Explicit source limitations

- Undo and redo display “not available” dialogs; custom standalone UndoRedo is a TODO.
- “Export as Mod” displays a planned/not-implemented dialog.
- Help opens a placeholder repository wiki URL.
- Cut, copy, paste, select-all, keyboard-shortcut help, and some menu items have no implemented match branch.
- No current graphical/exported-app evidence proves the preset opens this scene, saves correctly on each OS, or supports the advertised editor tools end to end.

The focused round-trip proof in `docs/EDITOR_ROUNDTRIP_PROOF.md` exercises save, export-folder, reload, and actor survival through the underlying model path. It explicitly does not prove live standalone UI interaction.

## Export caution

The preset's custom feature exists, while `project.godot` still names the main menu as the project main scene. `game/main_entry.gd` contains standalone-editor routing, but that scene is not the configured project main scene. The entry/export route therefore needs a real exported-build check before documentation can call the preset functional.

## Required product proof

- Export the exact preset with Godot 4.7 templates.
- Confirm the binary starts `standalone/editor/main.tscn` or repair the entry route.
- Exercise every visible menu item and remove/disable inert affordances.
- Create, edit, save, close, reopen, and playtest a level.
- Verify invalid/corrupt files, permissions, paths, and overwrite behavior.
- Implement and test undo/redo and mod export, or remove those menu claims.
- Run Windows and any other supported OS artifact.

Until that evidence exists, the truthful status is **source prototype with a green focused data round-trip, not a shipped standalone editor**.
