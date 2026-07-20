# Steam Integration Boundary

> **Documentation status: maintained reference.** Steam support code is present, but GodotSteam and SteamMultiplayerPeer are not bundled or proven in this checkout.

## Current Proof Boundary

| Capability | Status | What is actually proven |
| --- | --- | --- |
| ENet fallback source | Present | Network code can select ENet when Steam is unavailable. |
| Multiplayer profile startup | PASS | `multiplayer_demo` reaches startup without proving peers connect. |
| Two-process ENet host/join | BLOCKED here | Sandbox policy prevents localhost socket creation. |
| Local Workshop simulation | PASS | Filesystem upload/download/cache/subscription model only. |
| Real Steam/GodotSteam client | BLOCKED | Extension, client, app ID, account, and runtime evidence are absent. |
| Real Steam Workshop | BLOCKED | No service upload/download evidence. |

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

Source presence does not establish API compatibility with a particular GodotSteam release. The integration must be tested against the exact extension version selected for the product.

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

Until the matrix above is recorded, the truthful statement is: **MODUS contains optional Steam integration code and a guarded fallback, while real Steam/GodotSteam and Workshop behavior remain unverified**.
