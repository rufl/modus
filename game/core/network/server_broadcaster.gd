class_name ServerBroadcaster
extends Node

signal server_found(server_info: Dictionary)
signal server_lost(address: String)

const BROADCAST_PORT: int = 7778
const BROADCAST_INTERVAL: float = 2.0
const SERVER_TIMEOUT: float = 10.0
const JSONHelperClass = preload("res://game/core/json_helper.gd")

var known_servers: Dictionary = {}

var _udp_server: UDPServer = null
var _udp_broadcast: PacketPeerUDP = null
var _broadcast_timer: Timer = null
var _is_broadcasting: bool = false


func _ready() -> void:
	# Start listening for broadcasts (clients)
	_start_listening()


func _process(_delta: float) -> void:
	# Process incoming UDP packets
	if _udp_server and _udp_server.is_listening():
		_udp_server.poll()
		while _udp_server.is_connection_available():
			var peer: PacketPeerUDP = _udp_server.take_connection()
			var packet: PackedByteArray = peer.get_packet()
			if packet.size() > 0:
				_handle_broadcast(peer.get_packet_ip(), packet)

	# Check for timed out servers
	_cleanup_stale_servers()


## Start broadcasting server info (server only)


func start_broadcasting(server_info: Dictionary) -> void:
	if _is_broadcasting:
		return

	_udp_broadcast = PacketPeerUDP.new()
	_udp_broadcast.set_broadcast_enabled(true)
	_udp_broadcast.set_dest_address("255.255.255.255", BROADCAST_PORT)

	_broadcast_timer = Timer.new()
	_broadcast_timer.wait_time = BROADCAST_INTERVAL
	_broadcast_timer.autostart = true
	_broadcast_timer.timeout.connect(_on_broadcast_timer.bind(server_info))
	add_child(_broadcast_timer)

	_is_broadcasting = true
	GameManager.get_core_system("logger").info("[ServerBroadcaster] Started broadcasting", "Core")


## Stop broadcasting


func stop_broadcasting() -> void:
	if _broadcast_timer:
		_broadcast_timer.queue_free()
		_broadcast_timer = null

	if _udp_broadcast:
		_udp_broadcast.close()
		_udp_broadcast = null

	_is_broadcasting = false
	GameManager.get_core_system("logger").info("[ServerBroadcaster] Stopped broadcasting", "Core")


## Start listening for server broadcasts (client)


func _start_listening() -> void:
	_udp_server = UDPServer.new()
	var err: Error = _udp_server.listen(BROADCAST_PORT)

	if err != OK:
		push_warning("[ServerBroadcaster] Failed to listen on port ", BROADCAST_PORT)
		return

	GameManager.get_core_system("logger").info(
		"[ServerBroadcaster] Listening for broadcasts on port " + " " + str(BROADCAST_PORT), "Core"
	)


## Refresh server list (force re-scan)


func refresh_servers() -> void:
	# Clear old servers
	known_servers.clear()

	# Send discovery request
	if _udp_broadcast == null:
		_udp_broadcast = PacketPeerUDP.new()
		_udp_broadcast.set_broadcast_enabled(true)

	_udp_broadcast.set_dest_address("255.255.255.255", BROADCAST_PORT)

	var request: Dictionary = {
		"type": "discovery_request", "timestamp": Time.get_unix_time_from_system()
	}
	_udp_broadcast.put_packet(JSONHelperClass.safe_stringify(request).to_utf8_buffer())


## Get list of known servers


func get_server_list() -> Array[Dictionary]:
	var servers: Array[Dictionary] = []
	for address: String in known_servers:
		var entry: Dictionary = known_servers[address]
		var info: Dictionary = entry["info"].duplicate()
		info["address"] = address
		info["ping"] = Time.get_unix_time_from_system() - entry["last_seen"]
		servers.append(info)
	return servers


func _on_broadcast_timer(server_info: Dictionary) -> void:
	if not _udp_broadcast:
		return

	var packet: Dictionary = {
		"type": "server_announce",
		"info": server_info,
		"timestamp": Time.get_unix_time_from_system()
	}

	var json_string: String = JSONHelperClass.safe_stringify(packet)
	_udp_broadcast.put_packet(json_string.to_utf8_buffer())


func _handle_broadcast(ip: String, packet: PackedByteArray) -> void:
	var json_str: String = packet.get_string_from_utf8()
	var json: JSON = JSON.new()

	if json.parse(json_str) != OK:
		return

	var data: Dictionary = json.data
	var packet_type: String = data.get("type", "")

	match packet_type:
		"server_announce":
			var info: Dictionary = data.get("info", {})
			info["address"] = ip

			var is_new: bool = not known_servers.has(ip)
			known_servers[ip] = {"info": info, "last_seen": Time.get_unix_time_from_system()}

			if is_new:
				server_found.emit(info)
				GameManager.get_core_system("logger").info(
					"[ServerBroadcaster] Found server: " + " " + str(info.get("name", ip)), "Core"
				)

		"discovery_request":
			# If we're a server, respond with our info
			var ns: Node = GameManager.get_core_system("network")
			if _is_broadcasting and ns and ns.dedicated_server:
				_send_direct_response(ip, ns.dedicated_server.get_server_info())


func _send_direct_response(ip: String, info: Dictionary) -> void:
	var peer: PacketPeerUDP = PacketPeerUDP.new()
	peer.set_dest_address(ip, BROADCAST_PORT)

	var packet: Dictionary = {
		"type": "server_announce", "info": info, "timestamp": Time.get_unix_time_from_system()
	}
	peer.put_packet(JSONHelperClass.safe_stringify(packet).to_utf8_buffer())
	peer.close()


func _cleanup_stale_servers() -> void:
	var current_time: float = Time.get_unix_time_from_system()
	var stale_addresses: Array = []

	for address: String in known_servers:
		var entry: Dictionary = known_servers[address]
		if current_time - entry["last_seen"] > SERVER_TIMEOUT:
			stale_addresses.append(address)

	for address: String in stale_addresses:
		known_servers.erase(address)
		server_lost.emit(address)
		GameManager.get_core_system("logger").info(
			"[ServerBroadcaster] Server lost: " + " " + str(address), "Core"
		)
