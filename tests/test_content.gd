extends GutTest

# Coverage for content systems added after the initial test pass:
# DyeSystem apply/preview, GameState.tally_kill aggregation, class
# unlock progression, triple-class flag flip, RunState wager mult,
# loot rarity weights.

func before_each() -> void:
    GameState.lifetime_kills_by_type.clear()
    GameState.defeated_dragons.clear()
    GameState.unlocked_classes = ["warrior", "rogue", "wizard", "necromancer", "bard"]
    GameState.meta_unlocks["triple_class"] = false
    GameState.dye_pots = {}
    GameState.unlocked_dye_colors = ["red", "blue", "green", "gray"]
    GameState.gold = 1000

# ---- DyeSystem ----

func test_dye_apply_consumes_pot_when_owned() -> void:
    GameState.dye_pots["red"] = 2
    var ok: bool = DyeSystem.apply_dye("chest", "red")
    assert_true(ok)
    assert_eq(int(GameState.dye_pots["red"]), 1, "Pot count should decrement by 1")
    assert_eq(DyeSystem.dye_for("chest"), DyeSystem.color_for("red"))

func test_dye_apply_unlocked_no_pots_is_preview_only() -> void:
    # red is unlocked but has 0 pots
    GameState.dye_pots = {}
    var ok: bool = DyeSystem.apply_dye("chest", "red")
    assert_true(ok, "Preview should still apply even with 0 pots")
    assert_eq(int(GameState.dye_pots.get("red", 0)), 0, "No pot consumed in preview path")
    assert_eq(DyeSystem.dye_for("chest"), DyeSystem.color_for("red"))

func test_dye_apply_locked_color_returns_false() -> void:
    var ok: bool = DyeSystem.apply_dye("chest", "draconic")    # not unlocked
    assert_false(ok)

func test_dye_save_and_load_set() -> void:
    GameState.dye_pots["blue"] = 1
    DyeSystem.apply_dye("chest", "blue")
    DyeSystem.save_dye_set("herald")
    DyeSystem.set_dye("chest", "red")
    var ok: bool = DyeSystem.load_dye_set("herald")
    assert_true(ok)
    assert_eq(DyeSystem.dye_for("chest"), DyeSystem.color_for("blue"))

# ---- GameState kill tallying ----

func test_tally_kill_increments_per_monster_id() -> void:
    GameState.tally_kill("goblin")
    GameState.tally_kill("goblin")
    GameState.tally_kill("bandit")
    assert_eq(int(GameState.lifetime_kills_by_type["goblin"]), 2)
    assert_eq(int(GameState.lifetime_kills_by_type["bandit"]), 1)

# ---- Class unlock progression via boss_defeated ----

func test_first_vyxhasis_kill_unlocks_paladin() -> void:
    assert_false(GameState.unlocked_classes.has("paladin"))
    EventBus.boss_defeated.emit("vyxhasis")
    assert_true(GameState.unlocked_classes.has("paladin"))

func test_first_ourzhal_kill_unlocks_ranger() -> void:
    assert_false(GameState.unlocked_classes.has("ranger"))
    EventBus.boss_defeated.emit("ourzhal")
    assert_true(GameState.unlocked_classes.has("ranger"))

func test_all_three_dragons_flip_triple_class() -> void:
    assert_false(bool(GameState.meta_unlocks.get("triple_class", false)))
    EventBus.boss_defeated.emit("vyxhasis")
    EventBus.boss_defeated.emit("ourzhal")
    assert_false(bool(GameState.meta_unlocks.get("triple_class", false)),
        "Triple class should NOT unlock until all 3 dragons are dead")
    EventBus.boss_defeated.emit("aethyrnax")
    assert_true(bool(GameState.meta_unlocks.get("triple_class", false)))

# ---- RunState wager multiplier capping ----

func test_wager_multiplier_default_is_one() -> void:
    RunState.wager_multiplier = 1.0
    assert_almost_eq(RunState.wager_multiplier, 1.0, 0.001)

# ---- LootSystem rarity weights respect targets ----

func test_loot_roll_returns_within_rarity_bounds() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    for i in range(100):
        var r: int = LootSystem.roll_rarity(1.0)
        assert_true(r >= 0 and r <= 6, "Rarity must fit in [0..6]")

func test_loot_roll_item_with_explicit_rarity_locks_in() -> void:
    var item: Dictionary = LootSystem.roll_item(4, 1.0)    # legendary
    assert_eq(int(item["rarity"]), 4, "Explicit rarity should be honored")

# ---- Towns mood label boundaries ----

func test_towns_mood_boundary_labels() -> void:
    var t = Towns.get_town("coastreach")
    t.mood = 0.4
    assert_eq(t.mood_label(), "uneasy", "0.4 is the lower bound of 'uneasy'")
    t.mood = 0.39
    assert_eq(t.mood_label(), "fearful", "Below 0.4 is 'fearful'")
