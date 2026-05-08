extends Node

# NPCs remember player interactions. Used to color dialogue.

var memory: Dictionary = {}        # npc_id -> array of {kind, ts, payload}
const MAX_PER_NPC := 6

func record(npc_id: String, kind: String, payload: Dictionary = {}) -> void:
    if not memory.has(npc_id):
        memory[npc_id] = []
    var arr: Array = memory[npc_id]
    arr.push_front({"kind": kind, "ts": Time.get_ticks_msec() / 1000.0, "payload": payload})
    while arr.size() > MAX_PER_NPC:
        arr.pop_back()

func recent(npc_id: String) -> Array:
    return memory.get(npc_id, [])

func has_memory(npc_id: String, kind: String) -> bool:
    for m in recent(npc_id):
        if (m as Dictionary).get("kind","") == kind:
            return true
    return false

func dialogue_intro(npc_id: String, base: String) -> String:
    if has_memory(npc_id, "saved_caravan"):
        return "You're the one who saved my caravan. " + base + " 10% off, on the house."
    if has_memory(npc_id, "boss_kill"):
        return "I heard about the dragon. " + base
    if has_memory(npc_id, "first_visit"):
        return "Back so soon? " + base
    return base
