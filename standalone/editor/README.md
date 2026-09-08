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

The preset's `standalone_editor` custom feature selects `standalone/editor/main.tscn` through the project main-scene override; the normal client retains its main-menu route. Headless inspection of the exported Windows client and editor PCKs with Godot 4.7-dev1 confirms both routes load and their raw JSON/JSON5 configuration and remapped UI resources resolve. This resource-pack check does not prove native Windows startup or the standalone editor tools end to end.

## Required product proof

- Export the exact preset with Godot 4.7 templates.
- Confirm the native Windows binary starts `standalone/editor/main.tscn`.
- Exercise every visible menu item and remove/disable inert affordances.
- Create, edit, save, close, reopen, and playtest a level.
- Verify invalid/corrupt files, permissions, paths, and overwrite behavior.
- Implement and test undo/redo and mod export, or remove those menu claims.
- Run Windows and any other supported OS artifact.

Until that evidence exists, the truthful status is **source prototype with a green focused data round-trip, not a shipped standalone editor**.
