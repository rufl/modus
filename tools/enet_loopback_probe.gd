extends SceneTree

const DEFAULT_PORT := 7791
const TIMEOUT_SECONDS := 4.0

var _role := ""
var _port := DEFAULT_PORT
var _peer: ENetMultiplayerPeer
var _timer: SceneTreeTimer

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or (args[0] != "server" and args[0] != "client"):
		push_error("Usage: enet_loopback_probe.gd server|client [port]")
		quit(64)
		return
	_role = args[0]
	if args.size() > 1:
		_port = int(args[1])
	_peer = ENetMultiplayerPeer.new()
	if _role == "server":
		_start_server()
	else:
		_start_client()
	_timer = create_timer(TIMEOUT_SECONDS)
	_timer.timeout.connect(_on_timeout)

func _start_server() -> void:
	var error := _peer.create_server(_port, 1)
	if error != OK:
		push_error("ENet server creation failed: %s" % error)
		quit(1)
		return
	get_root().multiplayer.multiplayer_peer = _peer
	get_root().multiplayer.peer_connected.connect(_on_server_peer_connected)
	print("ENET_SERVER_LISTENING port=%d" % _port)

func _start_client() -> void:
	var error := _peer.create_client("127.0.0.1", _port)
	if error != OK:
		push_error("ENet client creation failed: %s" % error)
		quit(1)
		return
	get_root().multiplayer.multiplayer_peer = _peer
	get_root().multiplayer.connected_to_server.connect(_on_client_connected)
	print("ENET_CLIENT_CONNECTING port=%d" % _port)

func _on_server_peer_connected(peer_id: int) -> void:
	print("ENET_SERVER_PEER_CONNECTED id=%d" % peer_id)
	quit(0)

func _on_client_connected() -> void:
	print("ENET_CLIENT_CONNECTED")
	quit(0)

func _on_timeout() -> void:
	push_error("ENet loopback timed out waiting for connection")
	quit(1)

func _exit_tree() -> void:
	if get_root().multiplayer.multiplayer_peer == _peer:
		get_root().multiplayer.multiplayer_peer = null
	if _peer:
		_peer.close()
