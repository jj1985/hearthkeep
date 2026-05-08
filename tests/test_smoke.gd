extends GutTest

# Smoke test: every autoload registered in project.godot must resolve.
# Catches the regression class where a script is renamed/added but project.godot
# forgets to register the autoload (e.g. ChestManager / TrophyManager omission).

const REQUIRED_AUTOLOADS := [
    "WorldLore", "EventBus", "GameState", "SaveSystem", "RunState",
    "LootSystem", "DyeSystem", "Classes", "TalentDB", "PerkPool",
    "BuffSystem", "VendorSystem", "QuestSystem", "TravelSystem",
    "LoreCodex", "WorldSim", "WeatherSystem", "EventDirector",
    "FactionState", "NpcMemory", "RumorPool", "SfxBus", "MusicDirector",
    "VFX", "OrientationMgr", "Inventory", "ChestManager", "TrophyManager",
    "Settings",
]

func test_all_autoloads_resolve() -> void:
    for name in REQUIRED_AUTOLOADS:
        var node := get_tree().root.get_node_or_null(NodePath(name))
        assert_not_null(node, "Autoload '%s' missing from /root — check [autoload] in project.godot" % name)

func test_class_db_has_seven_base_classes() -> void:
    var classes: Array = Classes.names()
    assert_eq(classes.size(), 7, "Expected 7 base classes, got %d: %s" % [classes.size(), classes])

func test_class_db_has_ten_hybrid_prestiges() -> void:
    assert_eq(Classes.HYBRID_PRESTIGES.size(), 10, "Expected 10 named hybrid prestiges")

func test_chest_manager_initializes_all_chest_buckets() -> void:
    for d in ChestManager.CHEST_DEFS:
        var id: String = d["id"]
        assert_true(ChestManager.contents.has(id), "ChestManager missing chest bucket: %s" % id)
