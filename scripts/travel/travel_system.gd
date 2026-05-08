extends Node

# Permanent portals + Bond Stone (player-set hearthstone). Channels a teleport.

var unlocked_portals: Dictionary = {
    "valehome_keep": true,    # starting hub portal always unlocked
    "duskport_alley": false,
    "thalanore_canopy": false,
    "graymarrow_gate": false,
    "ashfen_outpost": false,
    "fearhollow_seal": false,
    "ruinmarch_camp": false,
}

var bond_location: String = "valehome_keep"
var bond_cooldown_until: float = 0.0
var bond_channel_time: float = 6.0    # seconds, interruptible
var channel_t: float = 0.0
var channeling: bool = false
var channel_target: String = ""

func unlock(portal_id: String) -> void:
    unlocked_portals[portal_id] = true
    EventBus.portal_unlocked.emit(portal_id)

func is_unlocked(portal_id: String) -> bool:
    return bool(unlocked_portals.get(portal_id, false))

func portal_destinations() -> Array:
    var out: Array = []
    for k in unlocked_portals.keys():
        if bool(unlocked_portals[k]):
            out.append(k)
    return out

func set_bond(location_id: String) -> bool:
    if not is_unlocked(location_id):
        return false
    bond_location = location_id
    EventBus.bond_set.emit(location_id)
    return true

func cooldown_remaining() -> float:
    return max(0.0, bond_cooldown_until - Time.get_ticks_msec() / 1000.0)

func can_channel(in_combat: bool) -> bool:
    if in_combat: return false
    return cooldown_remaining() <= 0.0

func begin_channel() -> bool:
    if channeling: return false
    channel_target = bond_location
    channel_t = bond_channel_time
    channeling = true
    EventBus.travel_started.emit(channel_target)
    return true

func interrupt_channel() -> void:
    if not channeling: return
    channeling = false
    channel_t = 0.0

func tick_channel(delta: float) -> bool:
    if not channeling: return false
    channel_t -= delta
    if channel_t <= 0.0:
        channeling = false
        bond_cooldown_until = Time.get_ticks_msec() / 1000.0 + 180.0   # 3 min
        EventBus.travel_completed.emit(channel_target)
        return true
    return false

func use_portal(portal_id: String) -> bool:
    if not is_unlocked(portal_id):
        return false
    EventBus.travel_started.emit(portal_id)
    EventBus.travel_completed.emit(portal_id)
    return true
