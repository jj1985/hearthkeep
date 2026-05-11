extends GutTest

# Verifies that the enemy types data is shaped correctly and wave gating
# matches our intent. The arena scene itself is too heavy to instantiate
# here, so we read ENEMY_TYPES off the script directly.

const HordeArena := preload("res://scripts/incremental/horde_arena.gd")

func _enemies() -> Dictionary:
    return HordeArena.ENEMY_TYPES

func test_basic_enemies_have_required_fields() -> void:
    for k in _enemies().keys():
        var def: Dictionary = _enemies()[k]
        assert_true(def.has("hp_base"), "%s missing hp_base" % k)
        assert_true(def.has("speed"),    "%s missing speed" % k)
        assert_true(def.has("gold"),     "%s missing gold" % k)
        assert_true(def.has("size"),     "%s missing size" % k)

func test_bosses_are_clearly_marked() -> void:
    for k in _enemies().keys():
        if String(k).begins_with("boss_"):
            assert_true(bool(_enemies()[k].get("boss", false)),
                "%s should set boss:true" % k)

func test_min_wave_monotonic_with_hp() -> void:
    # At minimum, the boss-tier elites should be tougher than the early
    # mob tier. Skeleton is the floor.
    var sk_hp: int = int(_enemies()["skeleton"]["hp_base"])
    for k in ["goblin", "skel_brute", "ghoul", "drake", "wraith", "ogre"]:
        assert_gt(int(_enemies()[k]["hp_base"]), sk_hp,
            "%s should have more HP than skeleton" % k)

func test_zone_resolution_walks_through_all_five() -> void:
    assert_eq(String(HordeArena._zone_for_wave(1)["name"]),  "Greenmarch")
    assert_eq(String(HordeArena._zone_for_wave(15)["name"]), "Ashen Vale")
    assert_eq(String(HordeArena._zone_for_wave(25)["name"]), "Frostwatch")
    assert_eq(String(HordeArena._zone_for_wave(35)["name"]), "Emberlands")
    assert_eq(String(HordeArena._zone_for_wave(99)["name"]), "The Void")

func test_eleven_normal_enemy_types_present() -> void:
    var normals: Array = []
    for k in _enemies().keys():
        if not bool(_enemies()[k].get("boss", false)):
            normals.append(k)
    assert_eq(normals.size(), 11)

func test_summoner_marked_as_summoning() -> void:
    assert_true(bool(_enemies()["summoner"].get("summons", false)))

func test_sapper_marked_as_exploding() -> void:
    assert_true(bool(_enemies()["sapper"].get("explodes", false)))

func test_shaman_marked_as_healing() -> void:
    assert_true(bool(_enemies()["shaman"].get("heals", false)))

func test_archer_marked_as_ranged() -> void:
    assert_true(bool(_enemies()["archer"].get("ranged", false)))

func test_three_named_bosses_present() -> void:
    var bosses: Array = []
    for k in _enemies().keys():
        if bool(_enemies()[k].get("boss", false)):
            bosses.append(k)
    assert_eq(bosses.size(), 3)
    assert_true(bosses.has("boss_warchief"))
    assert_true(bosses.has("boss_dragon"))
    assert_true(bosses.has("boss_aethyrnax"))
