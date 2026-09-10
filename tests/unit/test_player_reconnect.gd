extends ModusGutTestBase


class ReconnectProbe:
	extends PlayerSvc

	var requested_token: String = ""

	func request_reconnect(token: String) -> void:
		requested_token = token


func test_transport_loss_preserves_token_for_session_restore() -> void:
	var service := ReconnectProbe.new()
	add_child_autofree(service)
	service._active_tokens[service.multiplayer.get_unique_id()] = "session-token"

	service._on_network_connection_lost()
	service._active_tokens[service.multiplayer.get_unique_id()] = "replacement-token"
	service._on_network_reconnection_success()

	assert_eq(
		service.requested_token,
		"session-token",
		"Reconnect must use the pre-disconnect session token"
	)
	assert_true(
		service._pending_reconnect_token.is_empty(),
		"Consumed reconnect tokens must not be replayed"
	)


func test_reconnection_success_without_loss_does_not_send_token() -> void:
	var service := ReconnectProbe.new()
	add_child_autofree(service)
	service._active_tokens[service.multiplayer.get_unique_id()] = "session-token"

	service._on_network_reconnection_success()

	assert_true(
		service.requested_token.is_empty(),
		"Unpaired reconnect success must not request session restoration"
	)
