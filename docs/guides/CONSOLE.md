# Developer Console

> **Documentation status: maintained reference.** This page lists commands registered by the current dropdown console source. It does not certify every command in every runtime profile.

## Entry surface

- Scene: `game/ui/console/dropdown_console.tscn`
- Controller: `game/ui/console/dropdown_console.gd`
- Registry: `game/ui/console/console_command_registry.gd`
- Toggle keys: backtick or tilde

The dropdown console is skipped while `Engine.is_editor_hint()` is true. When open, it captures its text field and makes the mouse visible. Its command history is capped at 50 entries.

## Registered commands

The dropdown source currently registers only its core registry plus `CheatCommands`, `DebugCommands`, and `PlayerCommands`.

| Command | Arguments | Current source behavior |
| --- | --- | --- |
| `help` | none | Lists registered commands. |
| `clear` | none | Clears console output through the registry signal. |
| `god` | none | Toggles MatchSvc god mode when that service exists. |
| `noclip` | none | Toggles MatchSvc noclip when that service exists. |
| `give_weapon` | name or zero-based index | Switches the local authority player to a matching loaded weapon. |
| `give_ammo` | optional value ignored by current implementation | Refills available weapon ammo. |
| `heal` | none | Heals the local authority player to max health. |
| `debug_info` | none | Prints FPS, memory, node count, local player, match, and renderer details when available. |
| `fps` | none | Toggles the viewport overdraw debug view; despite the name, this is not a numeric FPS overlay. |
| `wireframe` | none | Toggles viewport wireframe debug drawing. |
| `reload_scene` | none | Reloads the current scene. |
| `teleport` | `x y z` | Sets the local authority player's global position. |
| `set_speed` | speed | Sets the current movement component's `move_speed`. |
| `respawn` | none | Calls the health death flow; it is not an immediate direct respawn. |
| `player_info` | none | Prints available local player, health, movement, and weapon state. |

`game/ui/console/commands/enemy_commands.gd` exists but is not registered by `DropdownConsole`; its commands are therefore not part of this documented console surface.

Old status/stat, spawn, killall, gravity, quit, and reset tables were not backed by the current dropdown registry and have been removed.

## Safety boundary

These are debug/cheat surfaces. Before any release export, verify whether the console scene is loaded, disable or authorize mutating commands as required, and audit multiplayer authority. The source methods often operate on the local authority player and are not a remote-admin protocol.

## Verification

Inspect the live registration points:

```bash
rg -n 'register_command\(' game/ui/console --glob '*.gd'
```

Manual proof still requires opening the console in a normal game session and exercising each visible command under the intended profile.
