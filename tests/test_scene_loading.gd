extends GutTest

# Asserts that load-bearing scenes parse and instantiate without errors.
# Catches missing-autoload-on-_ready bugs of the kind we hit with ChestManager.

const SCENES := {
    "title": "res://scenes/title.tscn",
    "run": "res://scenes/run.tscn",
    "villa": "res://scenes/villa/villa.tscn",
    "class_select": "res://scenes/ui/class_select.tscn",
    "player": "res://scenes/player/player.tscn",
    "goblin": "res://scenes/enemies/goblin.tscn",
    "loot_drop": "res://scenes/fx/loot_drop.tscn",
    "hud": "res://scenes/ui/hud.tscn",
    "chest_view": "res://scenes/ui/chest_view.tscn",
    "perk_picker": "res://scenes/ui/perk_picker.tscn",
}

func test_scenes_load_as_packed_scenes() -> void:
    for name in SCENES.keys():
        var path: String = SCENES[name]
        var ps: Resource = load(path)
        assert_not_null(ps, "Scene '%s' at %s failed to load" % [name, path])
        assert_true(ps is PackedScene, "Scene '%s' is not a PackedScene" % name)

func test_class_select_instantiates_clean() -> void:
    var ps: PackedScene = load("res://scenes/ui/class_select.tscn") as PackedScene
    assert_not_null(ps)
    var inst := ps.instantiate()
    assert_not_null(inst, "class_select failed to instantiate")
    add_child_autofree(inst)
    await get_tree().process_frame
    # ClassSelect controller creates 7 primary + 7 secondary buttons in _ready
    var primary_row: Node = inst.get_node_or_null("Scroll/Panel/Margin/V/PrimaryRow")
    assert_not_null(primary_row, "PrimaryRow node missing")
    assert_eq(primary_row.get_child_count(), 7, "Expected 7 primary class buttons")

func test_villa_instantiates_after_autoload_fix() -> void:
    # Pre-fix, this would have crashed because ChestManager autoload didn't exist.
    var ps: PackedScene = load("res://scenes/villa/villa.tscn") as PackedScene
    assert_not_null(ps)
    var inst := ps.instantiate()
    assert_not_null(inst, "villa scene failed to instantiate")
    add_child_autofree(inst)
    await get_tree().process_frame
