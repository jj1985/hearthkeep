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
    "vyxhasis_arena": "res://scenes/boss/vyxhasis_arena.tscn",
    "journal": "res://scenes/ui/journal.tscn",
    "forge_ui": "res://scenes/crafting/forge_ui.tscn",
    "talent_tree": "res://scenes/ui/talent_tree.tscn",
    "pause_menu": "res://scenes/ui/pause_menu.tscn",
    "game_over": "res://scenes/ui/game_over.tscn",
    "boss_bar": "res://scenes/ui/boss_bar.tscn",
    "settings": "res://scenes/ui/settings_screen.tscn",
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
    # ClassSelect controller populates the class list in _ready (7 rows).
    var class_list: Node = inst.get_node_or_null("SafeArea/V/Scroll/List")
    assert_not_null(class_list, "Class list node missing")
    assert_eq(class_list.get_child_count(), 7, "Expected 7 class rows populated")

func test_villa_instantiates_after_autoload_fix() -> void:
    # Pre-fix, this would have crashed because ChestManager autoload didn't exist.
    var ps: PackedScene = load("res://scenes/villa/villa.tscn") as PackedScene
    assert_not_null(ps)
    var inst := ps.instantiate()
    assert_not_null(inst, "villa scene failed to instantiate")
    add_child_autofree(inst)
    await get_tree().process_frame
