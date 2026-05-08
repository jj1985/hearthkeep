extends Node

# Faction reputation, power, and tokens. Persisted via SaveSystem.

var rep: Dictionary = {
    "coastreach_crown": 0,
    "bastion_consortium": 0,
    "canopyhall_council": 0,
    "kaeldur_clans": 0,
    "free_companies": 0,
}

var power: Dictionary = {
    "coastreach_crown": 50,
    "bastion_consortium": 50,
    "canopyhall_council": 50,
    "kaeldur_clans": 50,
    "free_companies": 50,
}

var tokens_dict: Dictionary = {
    "coastreach_crown": 0,
    "bastion_consortium": 0,
    "canopyhall_council": 0,
    "kaeldur_clans": 0,
    "free_companies": 0,
}

func add_rep(faction_id: String, amount: int) -> void:
    rep[faction_id] = int(rep.get(faction_id, 0)) + amount
    EventBus.faction_rep_changed.emit(faction_id, amount, rep[faction_id])

func tokens(faction_id: String) -> int:
    return int(tokens_dict.get(faction_id, 0))

func add_tokens(faction_id: String, amount: int) -> void:
    tokens_dict[faction_id] = int(tokens_dict.get(faction_id, 0)) + amount
    EventBus.currency_changed.emit("tokens:" + faction_id, amount, tokens_dict[faction_id])

func shift_power(faction_id: String, delta: int) -> void:
    power[faction_id] = clamp(int(power.get(faction_id, 50)) + delta, 0, 100)
    EventBus.faction_power_shifted.emit(faction_id, delta, power[faction_id])

func standing_label(faction_id: String) -> String:
    var r: int = int(rep.get(faction_id, 0))
    if r <= -2000: return "Hated"
    if r <= -500:  return "Hostile"
    if r <= -100:  return "Unfriendly"
    if r < 100:    return "Neutral"
    if r < 1000:   return "Friendly"
    if r < 5000:   return "Honored"
    if r < 12000:  return "Revered"
    return "Exalted"
