extends Node

# Lightweight world-event dispatcher. Tries to fire events on schedule when the
# player isn't in a critical state.

const EVENTS := [
    {"id":"goblin_raid","name":"Goblin Warband Raid","cooldown":480.0,"weight":4,
     "blurb":"Smoke on the horizon — defend the base."},
    {"id":"wandering_merchant","name":"Wandering Merchant","cooldown":360.0,"weight":6,
     "blurb":"A robed trader sets up at the gate. Rare stock for a short while."},
    {"id":"caravan_ambush","name":"Caravan Ambush","cooldown":600.0,"weight":3,
     "blurb":"A merchant caravan calls for aid on the world map."},
    {"id":"carnival","name":"Traveling Carnival","cooldown":900.0,"weight":2,
     "blurb":"Lanterns and dice and a drunk goblin who thinks he can cheat the house."},
    {"id":"dragon_flyover","name":"Dragon Flyover","cooldown":1500.0,"weight":1,
     "blurb":"A wing-shadow crosses the sun. The dragon is moving."},
]

var last_fired_at: Dictionary = {}
var elapsed: float = 0.0
var roll_interval: float = 90.0

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < roll_interval:
        return
    elapsed = 0.0
    _attempt_fire()

func _attempt_fire() -> void:
    var t: float = Time.get_ticks_msec() / 1000.0
    var pool: Array = []
    for ev in EVENTS:
        var last: float = float(last_fired_at.get(ev["id"], -10000.0))
        if t - last < float(ev["cooldown"]):
            continue
        pool.append(ev)
    if pool.is_empty():
        return
    var total := 0
    for ev in pool:
        total += int(ev["weight"])
    var r: int = randi() % int(max(1, total))
    var acc: int = 0
    for ev in pool:
        acc += int(ev["weight"])
        if r < acc:
            _fire(ev)
            return

func _fire(ev: Dictionary) -> void:
    last_fired_at[ev["id"]] = Time.get_ticks_msec() / 1000.0
    EventBus.world_event_started.emit(ev["id"], ev)

func force_fire(event_id: String) -> bool:
    for ev in EVENTS:
        if ev["id"] == event_id:
            _fire(ev)
            return true
    return false
