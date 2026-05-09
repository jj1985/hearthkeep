extends Node

# Quest system: data-driven quests, objective tracking, breadcrumb pinning.
# Quests live in /data/quests/*.json and are loaded on _ready.

var registry: Dictionary = {}              # quest_id -> quest definition
var active: Dictionary = {}                # quest_id -> progress dict
var completed: Array[String] = []
var pinned_quest_id: String = ""

func _ready() -> void:
    _seed_quests()
    EventBus.entity_killed.connect(_on_entity_killed)
    EventBus.boss_defeated.connect(_on_boss_defeated)
    EventBus.item_picked_up.connect(_on_item_picked_up)
    EventBus.world_event_started.connect(_on_world_event)

func _seed_quests() -> void:
    register({
        "id": "main_ch1_iron_tide",
        "title": "Chapter 1: The Iron Tide",
        "kind": "main",
        "blurb": "Goblin warbands are pouring out of the deep stone. Hold the line at the keep.",
        "objectives": [
            {"id":"slay_goblins","kind":"kill","target_id":"goblin","needed":15,"current":0,
             "label":"Defeat 15 goblins"},
            {"id":"defend","kind":"event","event_id":"goblin_raid","needed":1,"current":0,
             "label":"Survive a Goblin Warband Raid"},
        ],
        "reward": {"gold": 500, "tokens": {"coastreach_crown": 25}},
    })
    register({
        "id": "class_warrior_oath",
        "title": "Warrior: The Iron Oath",
        "kind": "class",
        "class_id": "warrior",
        "blurb": "Stand at the broken keep where Sir Alric fell. Take up his blade.",
        "objectives": [
            {"id":"reach","kind":"reach","location":"coastreach","needed":1,"current":0,"label":"Reach the Coastreach"},
            {"id":"fell_warchief","kind":"kill","target_id":"goblin_warchief","needed":1,"current":0,"label":"Slay a Goblin Warchief"},
        ],
        "reward": {"gold": 200, "skill_unlock":"oath_break", "cosmetic":"alric_helm"},
    })
    register({
        "id": "class_rogue_blackveil",
        "title": "Rogue: Of Shadow and Coin",
        "kind": "class",
        "class_id": "rogue",
        "objectives": [
            {"id":"silent_kills","kind":"kill","target_id":"goblin","needed":10,"current":0,"label":"Eliminate 10 goblins"},
            {"id":"steal","kind":"item","item_id":"ancient_coin","needed":3,"current":0,"label":"Lift 3 Ancient Coins"},
        ],
        "reward":{"gold": 200, "skill_unlock":"shadow_pact", "cosmetic":"blackveil_hood"},
    })
    register({
        "id":"class_wizard_archive",
        "title":"Wizard: The Archive of Embers",
        "kind":"class",
        "class_id":"wizard",
        "objectives":[
            {"id":"read","kind":"lore","entry_id":"sundering_intro","needed":1,"current":0,"label":"Read the Sundering Codex"},
            {"id":"slay_shaman","kind":"kill","target_id":"goblin_shaman","needed":5,"current":0,"label":"Silence 5 Goblin Shamans"},
        ],
        "reward":{"gold":200,"skill_unlock":"ember_shroud","cosmetic":"archive_cowl"},
    })
    register({
        "id":"class_necromancer_hollow",
        "title":"Necromancer: The Hollow Pact",
        "kind":"class","class_id":"necromancer",
        "objectives":[
            {"id":"corpses","kind":"kill","target_id":"goblin","needed":20,"current":0,"label":"Provide 20 corpses"},
            {"id":"shrine","kind":"reach","location":"veiled_plane","needed":1,"current":0,"label":"Visit a Veiled Plane shrine"},
        ],
        "reward":{"gold":200,"skill_unlock":"bone_throne","cosmetic":"hollow_sash"},
    })
    register({
        "id":"class_bard_sevenstrings",
        "title":"Bard: The Seven Strings",
        "kind":"class","class_id":"bard",
        "objectives":[
            {"id":"perform","kind":"event","event_id":"carnival","needed":1,"current":0,"label":"Perform at the Traveling Carnival"},
            {"id":"strings","kind":"item","item_id":"dragons_tear","needed":1,"current":0,"label":"Tune a string with a Dragon's Tear"},
        ],
        "reward":{"gold":200,"skill_unlock":"final_chord","cosmetic":"seven_strings_cape"},
    })
    register({
        "id":"dragon_hunt_vyxhasis",
        "title":"Dragon Hunt: Vyxhasis the Unburned",
        "kind":"dragon_hunt",
        "blurb":"A wing-shadow that does not move with the wind. The first hunt begins.",
        "chapters": [
            {"id":"gather_lore","label":"Read 3 dragon lore entries","needed":3,"current":0,"kind":"lore"},
            {"id":"forge_key","label":"Forge the Drake Key (gather 3 Drake Scales)","needed":3,"current":0,"kind":"item","item_id":"drake_scale"},
            {"id":"flyover_witness","label":"Witness the Dragon Flyover","needed":1,"current":0,"kind":"event","event_id":"dragon_flyover"},
            {"id":"confront","label":"Defeat Vyxhasis","needed":1,"current":0,"kind":"boss","target_id":"vyxhasis"},
        ],
        "reward":{"gold":2000,"dragon_shards":50,"cosmetic":"vyxhasis_horn"},
    })

func register(q: Dictionary) -> void:
    registry[q["id"]] = q

func start(quest_id: String) -> bool:
    if not registry.has(quest_id) or active.has(quest_id) or completed.has(quest_id):
        return false
    var q: Dictionary = registry[quest_id]
    var prog := {"id": quest_id, "objectives": q.get("objectives", q.get("chapters", [])).duplicate(true), "started_at": Time.get_ticks_msec() / 1000.0}
    active[quest_id] = prog
    EventBus.quest_started.emit(quest_id)
    if pinned_quest_id == "":
        pin(quest_id)
    return true

func pin(quest_id: String) -> void:
    pinned_quest_id = quest_id
    EventBus.quest_pinned.emit(quest_id)

func progress(quest_id: String, objective_id: String, amount: int = 1) -> void:
    if not active.has(quest_id):
        return
    var prog: Dictionary = active[quest_id]
    for obj in prog["objectives"]:
        if (obj as Dictionary)["id"] == objective_id:
            (obj as Dictionary)["current"] = min(int((obj as Dictionary)["current"]) + amount, int((obj as Dictionary)["needed"]))
            EventBus.quest_objective_progress.emit(quest_id, objective_id, int((obj as Dictionary)["current"]), int((obj as Dictionary)["needed"]))
    _check_completion(quest_id)

func _check_completion(quest_id: String) -> void:
    var prog: Dictionary = active[quest_id]
    var all_done := true
    for obj in prog["objectives"]:
        if int((obj as Dictionary)["current"]) < int((obj as Dictionary)["needed"]):
            all_done = false
            break
    if all_done:
        active.erase(quest_id)
        completed.append(quest_id)
        var q: Dictionary = registry[quest_id]
        var reward: Dictionary = q.get("reward", {})
        if reward.has("gold"):
            GameState.add_gold(int(reward["gold"]))
        if reward.has("dragon_shards"):
            GameState.add_gems(int(reward["dragon_shards"]))
        if reward.has("tokens"):
            for fid in (reward["tokens"] as Dictionary).keys():
                FactionState.add_tokens(fid, int((reward["tokens"] as Dictionary)[fid]))
        var title: String = String(q.get("title", quest_id))
        EventBus.floating_text.emit("QUEST COMPLETE — " + title.to_upper(), Vector2.ZERO, Color(0.45, 0.85, 0.45))
        SfxBus.play("quest_complete", -2.0)
        EventBus.quest_completed.emit(quest_id)

func get_active_list() -> Array:
    var out: Array = []
    for k in active.keys():
        out.append(active[k])
    return out

func _on_entity_killed(entity, _killer) -> void:
    var id_hint: String = ""
    if entity is Node and (entity as Node).has_method("monster_id"):
        id_hint = (entity as Object).call("monster_id")
    else:
        id_hint = "goblin"
    for qid in active.keys():
        for obj in active[qid]["objectives"]:
            if (obj as Dictionary).get("kind","") != "kill":
                continue
            var target_id: String = String((obj as Dictionary).get("target_id",""))
            if target_id == "any" \
                or target_id == id_hint \
                or id_hint.begins_with(target_id + "_") \
                or (target_id == "goblin" and id_hint.begins_with("goblin")):
                progress(qid, (obj as Dictionary)["id"], 1)

func _on_boss_defeated(boss_id: String) -> void:
    for qid in active.keys():
        for obj in active[qid]["objectives"]:
            if (obj as Dictionary).get("kind","") == "boss" and (obj as Dictionary).get("target_id","") == boss_id:
                progress(qid, (obj as Dictionary)["id"], 1)

func _on_item_picked_up(item: Dictionary) -> void:
    var item_id: String = str(item.get("base", item.get("id","")))
    for qid in active.keys():
        for obj in active[qid]["objectives"]:
            if (obj as Dictionary).get("kind","") == "item" and (obj as Dictionary).get("item_id","") == item_id:
                progress(qid, (obj as Dictionary)["id"], 1)

func _on_world_event(event_id: String, _payload) -> void:
    for qid in active.keys():
        for obj in active[qid]["objectives"]:
            if (obj as Dictionary).get("kind","") == "event" and (obj as Dictionary).get("event_id","") == event_id:
                progress(qid, (obj as Dictionary)["id"], 1)

func mark_lore_read(entry_id: String) -> void:
    for qid in active.keys():
        for obj in active[qid]["objectives"]:
            if (obj as Dictionary).get("kind","") == "lore" and ((obj as Dictionary).get("entry_id","") == entry_id or (obj as Dictionary).get("entry_id","") == ""):
                progress(qid, (obj as Dictionary)["id"], 1)

func mark_location_reached(location_id: String) -> void:
    for qid in active.keys():
        for obj in active[qid]["objectives"]:
            if (obj as Dictionary).get("kind","") == "reach" and (obj as Dictionary).get("location","") == location_id:
                progress(qid, (obj as Dictionary)["id"], 1)

func bounty_board() -> Array:
    return [
        {"id":"bounty_skirmishers","title":"Bounty: Goblin Skirmishers","desc":"Slay 8 skirmishers.","reward_gold":120},
        {"id":"bounty_chieftain","title":"Bounty: A Warchief","desc":"Slay 1 Goblin Warchief.","reward_gold":300},
        {"id":"bounty_drakes","title":"Bounty: Drake Scales","desc":"Bring back 5 Drake Scales.","reward_gold":250,"reward_dragon_shards":2},
    ]
