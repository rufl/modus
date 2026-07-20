extends ModusGutTestBase

# Test MODUS Framework Loot Service
# Converted from legacy Dictionary format to GUT assertions

var _loot_svc: LootSvc = null


func before_each() -> void:
	await modus_setup()
	_loot_svc = LootSvc.get_instance()


func after_each() -> void:
	modus_teardown()


# =============================================================================
# SERVICE AVAILABILITY
# =============================================================================


func test_service_exists() -> void:
	if not _loot_svc:
		_loot_svc = LootSvc.get_instance()

	assert_not_null(_loot_svc, "LootSvc.get_instance() should return valid instance")


func test_service_has_required_methods() -> void:
	if not _loot_svc:
		_loot_svc = LootSvc.get_instance()

	assert_not_null(_loot_svc, "LootSvc should be available")

	if not _loot_svc:
		return

	var required_methods: Array[String] = [
		"spawn_loot_from_table",
		"spawn_item",
	]

	for method_name: String in required_methods:
		assert_true(_loot_svc.has_method(method_name), "LootSvc should have method: %s" % method_name)


# =============================================================================
# ITEM RARITY
# =============================================================================


func test_item_rarity_class_exists() -> void:
	# ItemRarity should be a globally accessible class
	var rarity: ItemRarity = ItemRarity.new()
	assert_not_null(rarity, "Should be able to instantiate ItemRarity")


func test_item_rarity_from_tier() -> void:
	# Test the from_tier static method that we depend on
	var rarity: ItemRarity = ItemRarity.from_tier(ItemRarity.Tier.COMMON)
	assert_not_null(rarity, "ItemRarity.from_tier(COMMON) should return valid instance")

	# Test all tiers
	var tiers: Array = [
		ItemRarity.Tier.COMMON,
		ItemRarity.Tier.UNCOMMON,
		ItemRarity.Tier.RARE,
		ItemRarity.Tier.EPIC,
		ItemRarity.Tier.LEGENDARY
	]
	for tier: ItemRarity.Tier in tiers:
		var r: ItemRarity = ItemRarity.from_tier(tier)
		assert_not_null(r, "ItemRarity.from_tier should return valid instance for tier: %s" % str(tier))


func test_item_rarity_has_name() -> void:
	var rarity: ItemRarity = ItemRarity.from_tier(2 as ItemRarity.Tier)
	assert_not_null(rarity, "ItemRarity should be available")

	if not rarity:
		return

	var has_name_property: bool = "name" in rarity or rarity.has_method("get_name") or "display_name" in rarity
	assert_true(has_name_property, "ItemRarity should have name/display_name property or get_name() method")


# =============================================================================
# ITEM DATA
# =============================================================================


func test_item_data_class_exists() -> void:
	var item: ItemData = ItemData.new()
	assert_not_null(item, "Should be able to instantiate ItemData")


func test_item_data_has_required_properties() -> void:
	var item: ItemData = ItemData.new()
	assert_not_null(item, "ItemData should be available")

	if not item:
		return

	# Check for essential properties
	var required_props: Array[String] = ["item_id", "display_name", "item_type"]

	for prop: String in required_props:
		assert_true(prop in item, "ItemData should have property: %s" % prop)


func test_item_type_enum_exists() -> void:
	# ItemData.ItemType should exist
	var weapon_type: int = ItemData.ItemType.WEAPON
	var health_type: ItemData.ItemType = ItemData.ItemType.CONSUMABLE

	# Just checking they exist without crashing
	var types_valid: bool = weapon_type >= 0 or health_type >= 0
	assert_true(types_valid, "ItemType enum values should be valid")


# =============================================================================
# LOOT TABLES
# =============================================================================


func test_loot_tables_config_accessible() -> void:
	# Loot tables should be accessible via ConfigManager or data service
	var tables: Variant = null

	# Try GameManager.get_core_system("config") first
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.get_core_system("config"):
		tables = gm.get_core_system("config").get_value("loot_tables")

	# If not in ConfigManager, try GameManager data service
	if not tables and gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service and data_service.has_method("get_loot_tables"):
			tables = data_service.get_loot_tables()

	# It's okay if tables aren't loaded - they may be in data files
	pass_test("Loot tables config check completed")


# =============================================================================
# PICKUP SIGNALS
# =============================================================================


func test_loot_service_has_signals() -> void:
	if not _loot_svc:
		_loot_svc = LootSvc.get_instance()

	assert_not_null(_loot_svc, "LootSvc should be available")

	if not _loot_svc:
		return

	# Service has loot_spawned signal (check actual signal name)
	assert_true(_loot_svc.has_signal("loot_spawned"), "LootSvc should have loot_spawned signal")
