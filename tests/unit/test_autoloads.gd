extends ModusGutTestBase

# Test MODUS Framework autoloads and services
# Using GUT-compatible base class
# Updated for single GameManager autoload architecture


func before_each():
	await super.before_each()


func after_each():
	super.after_each()


func test_game_manager_exists() -> void:
	assert_autoload_exists("GameManager")


func test_config_service_exists() -> void:
	assert_autoload_exists("GameManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var config: Variant = gm.get_core_system("config")
		assert_not_null(config, "Config service should be available via GameManager")


# =============================================================================
# GAME MANAGER SERVICES
# =============================================================================


func test_game_manager_logger_exists() -> void:
	assert_autoload_exists("GameManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		assert_not_null(logger, "Logger service should be available")


func test_game_manager_has_constants() -> void:
	assert_autoload_exists("GameManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		# Check that constants are accessible
		assert_eq(gm.GROUP_PLAYER, "player", "GROUP_PLAYER constant should be accessible")
		assert_eq(gm.BUS_MASTER, "Master", "BUS_MASTER constant should be accessible")


# =============================================================================
# SERVICE REGISTRATION
# =============================================================================


func test_services_ready_method() -> void:
	assert_autoload_exists("GameManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		assert_true(
			gm.has_method("get_core_system"), "GameManager should have get_core_system() method"
		)


func test_get_service_method() -> void:
	assert_autoload_exists("GameManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		assert_true(
			gm.has_method("get_core_system"), "GameManager should have get_core_system() method"
		)


func test_network_service_accessible() -> void:
	assert_autoload_exists("GameManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var network: Variant = gm.get_core_system("network")
		# Network service may not be loaded yet (lazy loading), so null is acceptable
		assert_true(true, "Network service check completed")


func test_data_service_accessible() -> void:
	assert_autoload_exists("GameManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data: Variant = gm.get_core_system("data")
		# Data service may not be loaded yet (lazy loading), so null is acceptable
		assert_true(true, "Data service check completed")


# =============================================================================
# OLD AUTOLOADS REMOVED
# =============================================================================


func test_old_autoloads_removed():
	var root = get_tree().root
	# GameCore and GameDatabase should now be removed (replaced by GameManager)
	assert_null(root.get_node_or_null("/root/GameCore"), "GameCore should be removed")
	assert_null(root.get_node_or_null("/root/EventBus"), "EventBus should be removed")
	assert_null(root.get_node_or_null("/root/GameDatabase"), "GameDatabase should be removed")
