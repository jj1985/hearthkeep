extends GutTest

# Save round-trip — write GameState fields, save to disk, mutate in-
# memory, load, verify everything came back. Catches save-format
# regressions when fields are added/removed.

var _saved_gold: int
var _saved_dragons: Array[String]
var _saved_unlocked_classes: Array[String]
var _saved_dye_pots: Dictionary
var _saved_krrik: bool
var _saved_kills_by_type: Dictionary

func before_each() -> void:
    # Snapshot the existing GameState so the test can restore on teardown
    _saved_gold = GameState.gold
    _saved_dragons = GameState.defeated_dragons.duplicate()
    _saved_unlocked_classes = GameState.unlocked_classes.duplicate()
    _saved_dye_pots = GameState.dye_pots.duplicate(true)
    _saved_krrik = GameState.krrik_defeated
    _saved_kills_by_type = GameState.lifetime_kills_by_type.duplicate(true)

func after_each() -> void:
    GameState.gold = _saved_gold
    GameState.defeated_dragons = _saved_dragons.duplicate()
    GameState.unlocked_classes = _saved_unlocked_classes.duplicate()
    GameState.dye_pots = _saved_dye_pots.duplicate(true)
    GameState.krrik_defeated = _saved_krrik
    GameState.lifetime_kills_by_type = _saved_kills_by_type.duplicate(true)
    SaveSystem.save()

func test_save_then_load_round_trips_gold_and_dragons() -> void:
    GameState.gold = 12345
    GameState.defeated_dragons = ["vyxhasis", "ourzhal"]
    SaveSystem.save()
    GameState.gold = 0
    GameState.defeated_dragons.clear()
    var ok: bool = SaveSystem.load_save()
    assert_true(ok)
    assert_eq(GameState.gold, 12345)
    assert_eq(GameState.defeated_dragons.size(), 2)
    assert_true(GameState.defeated_dragons.has("vyxhasis"))
    assert_true(GameState.defeated_dragons.has("ourzhal"))

func test_save_round_trips_unlocked_classes() -> void:
    GameState.unlocked_classes = ["warrior", "rogue", "wizard", "necromancer", "bard", "paladin"]
    SaveSystem.save()
    GameState.unlocked_classes.clear()
    SaveSystem.load_save()
    assert_eq(GameState.unlocked_classes.size(), 6)
    assert_true(GameState.unlocked_classes.has("paladin"))

func test_save_round_trips_krrik_flag() -> void:
    GameState.krrik_defeated = true
    SaveSystem.save()
    GameState.krrik_defeated = false
    SaveSystem.load_save()
    assert_true(GameState.krrik_defeated)

func test_save_round_trips_dye_pots() -> void:
    GameState.dye_pots = {"red": 3, "blue": 1, "draconic": 1}
    SaveSystem.save()
    GameState.dye_pots = {}
    SaveSystem.load_save()
    assert_eq(int(GameState.dye_pots.get("red", 0)), 3)
    assert_eq(int(GameState.dye_pots.get("blue", 0)), 1)
    assert_eq(int(GameState.dye_pots.get("draconic", 0)), 1)

func test_save_round_trips_kills_by_type() -> void:
    GameState.lifetime_kills_by_type = {"goblin": 42, "bandit": 7, "drake": 1}
    SaveSystem.save()
    GameState.lifetime_kills_by_type = {}
    SaveSystem.load_save()
    assert_eq(int(GameState.lifetime_kills_by_type.get("goblin", 0)), 42)
    assert_eq(int(GameState.lifetime_kills_by_type.get("bandit", 0)), 7)
    assert_eq(int(GameState.lifetime_kills_by_type.get("drake", 0)), 1)
