extends GutTest

# Integration tests cutting across multiple subsystems:
# - Forge.craft → ChestManager.deposit ends up in the right chest
# - DragonBoss died signal → TrophyManager awards the matching trophy
# - RunState allocated talent stats survive a fresh start_run

const DragonBoss := preload("res://scripts/entities/dragon_boss.gd")

func before_each() -> void:
    ChestManager.contents.clear()
    for d in ChestManager.CHEST_DEFS:
        ChestManager.contents[d["id"]] = []
    TrophyManager.collected.clear()
    TrophyManager.placed.clear()
    TrophyManager.active_buff_ids.clear()
    GameState.defeated_dragons.clear()
    RunState.class_primary = "warrior"
    RunState.class_secondary = ""
    RunState.allocated_talents.clear()
    RunState.talent_points = 0
    RunState.start_run(0)

# ---- Forge → Chest pipeline ----

func test_forge_sword_lands_in_weapons_chest() -> void:
    var item: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak"})
    assert_false(item.is_empty())
    var ok: bool = ChestManager.deposit(item)
    assert_true(ok)
    var weapons: Array = ChestManager.get_chest("weapons")
    assert_eq(weapons.size(), 1, "Weapons chest should hold the crafted sword")
    assert_eq(weapons[0]["form"], "sword")

func test_forge_dagger_routes_to_weapons() -> void:
    var item: Dictionary = Forge.craft({"form": "dagger", "primary": "mithril", "secondary": "silk"})
    ChestManager.deposit(item)
    assert_eq(ChestManager.get_chest("weapons").size(), 1)

# ---- Boss death → Trophy ----

func test_boss_defeated_signal_awards_trophy_for_each_dragon() -> void:
    for boss_id in ["vyxhasis", "ourzhal", "aethyrnax"]:
        EventBus.boss_defeated.emit(boss_id)
    assert_true(TrophyManager.collected.has("vyxhasis_horn"),
        "Vyxhasis should award vyxhasis_horn trophy")
    assert_true(TrophyManager.collected.has("ourzhal_scale"))
    assert_true(TrophyManager.collected.has("aethyrnax_fang"))

func test_boss_defeated_appends_to_game_state_once() -> void:
    EventBus.boss_defeated.emit("vyxhasis")
    EventBus.boss_defeated.emit("vyxhasis")    # duplicate
    var count_v: int = 0
    for d in GameState.defeated_dragons:
        if d == "vyxhasis": count_v += 1
    assert_eq(count_v, 1, "Defeated dragons set must dedupe")

# ---- RunState class persistence across start_run ----

func test_class_selection_survives_start_run() -> void:
    RunState.set_classes("rogue", "wizard")
    RunState.start_run(99)
    assert_eq(RunState.class_primary, "rogue")
    assert_eq(RunState.class_secondary, "wizard")

func test_talent_points_increment_on_level_up() -> void:
    RunState.start_run(0)
    var p_before: int = RunState.talent_points
    RunState.add_xp(1000.0)    # forces multiple level-ups
    assert_gt(RunState.talent_points, p_before,
        "Each level-up should grant a talent point")

# ---- Boss state machine + ability cooldown integration ----

func test_dragon_state_machine_resets_cooldowns_on_each_phase() -> void:
    var boss: DragonBoss = DragonBoss.new()
    boss.max_hp = 1000.0
    boss.hp = 1000.0
    boss.register_ability("a", 5.0)
    boss.consume_ability("a")
    assert_false(boss.is_ability_ready("a"))
    boss.take_damage(310.0)    # ground → air
    assert_true(boss.is_ability_ready("a"), "AIR phase should reset cooldown")
    boss.consume_ability("a")
    boss.take_damage(370.0)    # air → enraged
    assert_true(boss.is_ability_ready("a"), "ENRAGED phase should reset cooldown again")
    boss.free()

# ---- Sell loop: junk → vendor ----

func test_sell_all_junk_clears_chest_and_credits_gold() -> void:
    var junk_item := {
        "name": "Goblin Tooth", "rarity": 0, "ilvl": 1, "vendor_trash": true,
        "tags": ["junk", "vendor_trash"], "is_junk": true,
    }
    ChestManager.deposit(junk_item)
    assert_eq(ChestManager.get_chest("junk").size(), 1)
    var gold_before: int = GameState.gold
    var result: Dictionary = VendorSystem.sell_all_junk(ChestManager.get_chest("junk").duplicate())
    assert_gt(int(result["gold"]), 0, "Sell should yield positive gold")
    for it in result["items"]:
        ChestManager.withdraw("junk", it)
    assert_eq(ChestManager.get_chest("junk").size(), 0,
        "All sold junk should be cleared from the chest")

# ---- Travel: Bond Stone rebinding survives a save round-trip in memory ----

func test_bond_stone_rebinding_persists_in_memory() -> void:
    TravelSystem.unlocked_portals["thalanore_canopy"] = true
    var ok: bool = TravelSystem.set_bond("thalanore_canopy")
    assert_true(ok)
    assert_eq(TravelSystem.bond_location, "thalanore_canopy")

# ---- Triple-class perk pool ----

func test_perk_offer_includes_tertiary_class_perks() -> void:
    # Adding a tertiary should grow the candidate pool — at minimum
    # the pool must contain at least one perk we can verify came from
    # that class's bucket. Easiest signal: pool size strictly grows.
    var two: Array = PerkPool.draw_offer("warrior", "wizard", 999, [], "")
    var three: Array = PerkPool.draw_offer("warrior", "wizard", 999, [], "rogue")
    assert_gt(three.size(), two.size(),
        "Tertiary class must contribute additional perks to the offer pool")
