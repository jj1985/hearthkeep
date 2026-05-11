extends GutTest

# Daily quest tick + claim flow.

func before_each() -> void:
    GameState.gold = 0
    GameState.embers = 0
    GameState.daily_quest = {
        "target_id": "goblin",
        "target_count": 3,
        "progress": 0,
        "reward_gold": 50,
        "reward_ember": 2,
        "claimed": false,
    }
    HordeState.reset_run()

func test_kill_of_target_type_increments_progress() -> void:
    HordeState.record_kill("goblin", 0)
    assert_eq(int(GameState.daily_quest["progress"]), 1)

func test_kill_of_other_type_does_not_increment() -> void:
    HordeState.record_kill("skeleton", 0)
    assert_eq(int(GameState.daily_quest["progress"]), 0)

func test_completing_quest_awards_gold_and_ember_and_marks_claimed() -> void:
    for i in 3:
        HordeState.record_kill("goblin", 0)
    assert_true(bool(GameState.daily_quest["claimed"]))
    assert_eq(GameState.gold, 50)
    assert_eq(GameState.embers, 2)

func test_post_claim_kills_dont_re_award() -> void:
    for i in 5:
        HordeState.record_kill("goblin", 0)
    var gold0 := GameState.gold
    var ember0 := GameState.embers
    HordeState.record_kill("goblin", 0)
    assert_eq(GameState.gold, gold0)
    assert_eq(GameState.embers, ember0)
