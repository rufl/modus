# Steam Integration Boundary

> **Documentation status: maintained reference.** Steam support code is present; GodotSteam 4.22.1 was locally installed and authenticated API initialization was observed on September 10, 2026. This does not establish multi-account, Workshop, relay, or production-server proof.

## Current Proof Boundary

| Capability | Status | What is actually proven |
| --- | --- | --- |
| ENet fallback source | Present | Network code can select ENet when Steam is unavailable. |
| Multiplayer profile startup | PASS | `multiplayer_demo` reaches startup without proving peers connect. |
| Two-process ENet host/join | PASS | Separate Godot server/client smoke connected over localhost; server is terminated after client success |
| Local Workshop simulation | PASS | Filesystem upload/download/cache/subscription model only |
| Real Steam/GodotSteam client | FOCUSED PASS | GodotSteam 4.22.1 / Godot 4.7.2 Linux runtime initialized through the authenticated Steam client; Steam ID and persona were returned; integration suite passes 8/8 |
| Real Steam Workshop | BLOCKED | No configured app-owned Workshop item or two-account service evidence |

## Live source

- Steam adapter: `game/core/network/steam_manager.gd`
- Network service: `game/scripts/features/network/network_service.gd`
- Network manager: `game/core/network/network_manager.gd`
- Network config: `game/config/network/network_config.json5`

`SteamManager` is created by the network service. It is not declared as a project autoload. Current configuration keys include `use_steam` and `fallback_to_enet`; old guidance using `use_steam_networking` or a SteamManager autoload path is obsolete.

## Code surface

The adapter contains guarded code for:

- detecting the `Steam` singleton;
- client/server initialization;
- lobby create/join/list/data calls;
- auth tickets;
- achievements;
- optional `SteamMultiplayerPeer` host/client creation;
- ENet fallback selection.

Source presence and one-account initialization do not establish API compatibility or production behavior across the full matrix. The tested local combination is Godot 4.7.2 with GodotSteam 4.22.1.

## External prerequisites

Real proof requires:

- a Godot 4.7-compatible GodotSteam extension;
- Steam runtime/client and native libraries for the target OS;
- an authorized Steam app ID and test accounts;
- SteamMultiplayerPeer if that transport is part of the target;
- configured Steamworks features and permissions;
- exported builds, not only editor/headless source checks.

Keep test app IDs and credentials out of source-controlled release configuration.

## Required validation matrix

- Steam absent: fallback behavior and errors.
- Steam client present: initialization, identity, callbacks, shutdown.
- Lobby create/list/join/leave with two accounts.
- Authentication success, rejection, expiry, and replay.
- Relay/P2P connect, disconnect, reconnect, and host loss.
- Dedicated-server registration if supported.
- Achievement behavior and offline/error handling if shipped.
- Workshop upload, browse, download, subscribe, update, and ownership errors.
- Windows/Linux behavior for the exact exported artifacts.

## Local simulation

Run the focused filesystem model through the GUT test documented in `docs/WORKSHOP_LOCAL_SIMULATION_PROOF.md`. It is useful for deterministic data-flow checks, but must always be labeled **local simulation**, never Steam service proof.

## Claim rule

Until the matrix above is recorded, the truthful statement is: **MODUS has one authenticated GodotSteam client/API initialization proof and a guarded ENet fallback; multi-account Steam, Workshop, relay, and production dedicated-server behavior remain unverified**.
