# MODUS Dedicated Server

> **Documentation status: maintained reference.** Dedicated-server source and an export preset exist. No current external client/server run proves a deployable production server.

## Current source

- Runtime node: `game/core/network/dedicated_server.gd`
- Network service wiring: `game/scripts/features/network/network_service.gd`
- Export preset: `Dedicated Server (Linux)` in `export_presets.cfg`
- Preset output path: `standalone/server/server.x86_64`
- Custom export feature: `dedicated_server`

The source enters dedicated mode only outside the editor and when one of these is present:

- the `dedicated_server` OS feature;
- `--dedicated-server`;
- `--modus-dedicated`;
- `MODUS_DEDICATED_SERVER=1`.

The old `--server` command is not the current activation contract.

## Configuration

The preferred file is `user://server_config.json5`; legacy JSON is read as a fallback. If neither exists, source creates defaults equivalent to:

```json
{
  "server_name": "Modus Server",
  "port": 7777,
  "max_players": 16,
  "map": "res://game/world/maps/showcase.tscn",
  "password": "",
  "mods": [],
  "difficulty": 1,
  "friendly_fire": false,
  "auto_save_interval": 300,
  "welcome_message": "Welcome to the server!"
}
```

These are code defaults, not recommended production capacity or security settings.

## Export and launch

Export the existing preset from Godot or the command line after installing matching templates. A source-shaped launch is:

```bash
./standalone/server/server.x86_64 --headless --dedicated-server
```

No server binary is committed at that path. Export success, socket binding, map load, client join, reconnect, mod loading, persistence, and shutdown must each be observed.

## Implemented source paths

`DedicatedServer` contains code to load JSON5/JSON configuration, scan configured mods, create an ENet server, load the configured map, advertise server information, schedule autosave, verify a simple password, send a welcome message, and optionally call the Steam adapter.

Source presence is not proof that all paths work together. Steam server behavior is blocked on real GodotSteam evidence.

## Required release evidence

- Exported Linux server starts with the intended feature profile.
- Server binds outside the restricted sandbox.
- At least two external clients join and exchange gameplay state.
- Invalid password/auth, malformed traffic, rate limits, and disconnects are tested.
- Map rotation/load, save/autosave, mods, and graceful shutdown are observed.
- Logs and configuration locations are recorded for each target OS.
- Soak, memory, CPU, bandwidth, and recovery evidence is captured.

Until then, describe this as **dedicated-server implementation scaffolding with no current deployment proof**.
