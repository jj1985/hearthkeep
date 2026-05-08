extends GutTest

# Towns Phase A: registry seeded with 3 towns, each with 5 named NPCs.
# Spec: docs/towns_design.md.

func test_three_towns_seeded() -> void:
    assert_eq(Towns.count(), 3, "Phase A should seed exactly 3 towns")

func test_each_town_has_five_npcs() -> void:
    for town in Towns.all_towns():
        assert_eq(town.npcs.size(), 5, "Town %s should have 5 named NPCs" % town.id)

func test_known_town_ids_present() -> void:
    for id in ["coastreach", "black_bastion", "canopyhall"]:
        assert_not_null(Towns.get_town(id), "Town %s missing" % id)

func test_each_town_has_ruler_with_name_and_title() -> void:
    for town in Towns.all_towns():
        assert_true(town.ruler.has("name"), "Town %s ruler missing name" % town.id)
        assert_true(town.ruler.has("title"), "Town %s ruler missing title" % town.id)
        assert_ne(String(town.ruler["name"]), "", "Empty ruler name for %s" % town.id)

func test_mood_label_buckets() -> void:
    var t = Towns.get_town("canopyhall")
    t.mood = 0.85
    assert_eq(t.mood_label(), "jubilant")
    t.mood = 0.65
    assert_eq(t.mood_label(), "content")
    t.mood = 0.45
    assert_eq(t.mood_label(), "uneasy")
    t.mood = 0.25
    assert_eq(t.mood_label(), "fearful")
    t.mood = 0.05
    assert_eq(t.mood_label(), "despairing")

func test_summary_shape() -> void:
    var s = Towns.get_town("coastreach").summary()
    for k in ["id", "name", "region", "population", "mood", "mood_label", "ruler_name", "ruler_title", "faction_lean", "npc_count", "recent_event"]:
        assert_true(s.has(k), "summary missing key '%s'" % k)
    assert_eq(s["npc_count"], 5)
