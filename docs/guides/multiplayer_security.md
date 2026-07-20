# Multiplayer Security Review Guide

> **Documentation status: maintained reference.** MODUS has security-oriented source controls, but no current penetration test, hostile-client matrix, or production security sign-off.

## Current controls in source

- RPC name allowlisting and calls-per-second metadata in `game/core/network/rpc_whitelist.gd`.
- Central `NetworkManager.validate_rpc()` flow in `game/core/network/network_manager.gd`.
- Selected validators for shooting, damage, weapon switching, pickups, revives, and movement.
- Trusted-peer and Steam-ticket support code.
- Server/client state snapshots and reconciliation code.
- Dedicated-server and chat paths.

These controls are partial. Most allowlist entries do not request semantic validation, and an allowlisted `any_peer` method can still be unsafe if its handler trusts payload data.

## Audit every RPC

Inventory current annotations:

```bash
rg -n '@rpc\(' game --glob '*.gd'
```

For each `any_peer` handler, record:

1. who may call it;
2. where server authority is enforced;
3. which allowlist/rate-limit entry applies;
4. which semantic validator runs;
5. which server-owned state is consulted;
6. maximum payload size/range;
7. denial behavior and logging;
8. tests for spoofing, replay, flooding, and malformed data.

## Minimum rules

- Reject unknown RPC names by default.
- Do not mutate authoritative gameplay state on a non-server peer.
- Derive sender identity from `multiplayer.get_remote_sender_id()`.
- Never accept client-calculated damage, ownership, inventory, health, score, or final transforms as authoritative.
- Bound strings, arrays, dictionaries, resource paths, and numeric values.
- Avoid accepting arbitrary NodePaths or resource paths from clients.
- Rate-limit before expensive work, then apply semantic checks.
- Keep admin/debug/editor RPCs disabled or strongly authorized in release profiles.
- Make disconnect/reconnect and duplicate-message behavior deterministic.

## Focused verification

Relevant tests include network manager, RPC whitelist, movement synchronization, weapon-state synchronization, multiplayer compatibility, and splitscreen/network integration files. Their exact latest outcomes must be read from current reports or rerun; this guide does not mark them collectively green.

Suggested focused commands:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_network_manager.gd

godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_rpc_whitelist.gd
```

## Runtime and external proof

Security closure requires at least:

- two or more real peers outside the restricted socket sandbox;
- malicious/replayed/oversized request tests;
- packet-loss, latency, reconnect, and host-loss tests;
- dedicated-server tests with untrusted clients;
- Steam authentication tests if Steam is supported;
- audit of debug/editor/admin surfaces in release exports;
- independent review of the actual supported threat model.

Until that evidence exists, describe MODUS as having **security-oriented validation code with open audit coverage**, not as cheat-proof or secure for hostile public servers.
