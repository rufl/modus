# Multiplayer Authority Model

> **Documentation status: maintained reference.** This is the intended security/authority contract plus the current implementation gap. It is not a production security certification.

## Intended contract

Gameplay-critical client actions should be requests. The server should validate the sender, authority, state, range, rate, and payload before mutating authoritative state, then replicate the accepted result. Client prediction may provide local responsiveness, but the server remains the correction source.

## Current implementation surfaces

| Surface | Source |
| --- | --- |
| Host/join, rate limiting, validators, snapshots, prediction reconciliation | `game/core/network/network_manager.gd` |
| RPC allowlist metadata | `game/core/network/rpc_whitelist.gd` |
| Movement input/prediction | `game/core/network/player_movement_predictor.gd` |
| Player weapon request/sync | `game/entities/player/components/weapon_network_sync.gd` |
| Networked level-editor actions | `game/core/network/network_editor.gd` |
| Chat request path | `game/scripts/features/network/chat_service.gd` |

`NetworkManager.validate_rpc()` rejects methods absent from `RPCWhitelist`, applies per-method rate limits, and invokes extra validators only for entries whose `requires_validation` flag is true.

## Important gap

Many allowlisted methods currently set `requires_validation` to false, and several gameplay scripts expose `@rpc("any_peer", ...)` methods. The whitelist is therefore a routing/rate-limit control, not proof that every RPC is server-authoritative or semantically validated.

Before release, every `any_peer` RPC must be audited at its actual handler. “Listed in the whitelist” is not enough.

## Required request pattern

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func request_action(payload: Dictionary) -> void:
    if not multiplayer.is_server():
        return

    var sender_id := multiplayer.get_remote_sender_id()
    var network := GameManager.get_core_system("network")
    if not network or not network.validate_rpc(sender_id, "request_action", [payload]):
        return

    if not _validate_action_state(sender_id, payload):
        return

    _apply_authoritative_action(sender_id, payload)
```

The exact validator must use server-known state. Never trust a client-provided position, damage value, inventory count, ownership ID, or cooldown timestamp without comparison to server state.

## Validation checklist

- Sender is a connected/known peer.
- Handler is executing on the server.
- Method is allowlisted and rate-limited.
- Payload types, sizes, ranges, and identifiers are bounded.
- Requested entity belongs to or is reachable by the sender.
- Distance/line-of-sight checks use server-known transforms.
- State transitions and cooldowns are legal.
- Replayed or duplicate requests are harmless or rejected.
- Denials do not leak privileged state.
- Accepted state is replicated by authority-owned RPCs.

## Reliability choices

- Use reliable delivery for infrequent critical state transitions where loss is unacceptable.
- Use unreliable delivery for high-frequency replaceable state such as movement samples.
- Delivery mode does not establish authority; validation is still required.

## Current proof boundary

Focused network-manager, whitelist, movement-sync, and multiplayer compatibility tests exist. [Current Status](CURRENT_STATUS.md) consolidates dated aggregate and September local real-ENet observations; older socket-sandbox reports are historical boundaries, not current capability checks. A refreshed full aggregate, latency/reconnect behavior, and real Steam/GodotSteam proof remain open.

Production closure requires a complete RPC audit, hostile-client tests, connected-peer runtime evidence, reconnect/state-recovery tests, and external review appropriate to the threat model.
