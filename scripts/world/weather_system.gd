extends Node

enum Weather { CLEAR, RAIN, STORM, FOG, ASHFALL }

var current: int = Weather.CLEAR
var next_roll_at: float = 60.0
var elapsed: float = 0.0

const ZONE_WEATHER := {
    "valehome": [Weather.CLEAR, Weather.RAIN, Weather.FOG],
    "ashfen":   [Weather.CLEAR, Weather.ASHFALL, Weather.STORM],
    "thalanore":[Weather.CLEAR, Weather.RAIN],
    "fearhollow":[Weather.FOG, Weather.STORM, Weather.CLEAR],
}

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= next_roll_at:
        elapsed = 0.0
        next_roll_at = randf_range(120.0, 240.0)
        _roll(WorldLore.WORLD_NAME, "")

func _roll(_world: String, zone_id: String) -> void:
    var pool: Array = ZONE_WEATHER.get(zone_id, [Weather.CLEAR, Weather.RAIN])
    var pick: int = pool[randi() % pool.size()]
    if pick != current:
        current = pick
        EventBus.weather_changed.emit(current_name())

func current_name() -> String:
    return ["clear","rain","storm","fog","ashfall"][current]

func fire_radius_mult() -> float:
    return 0.9 if current == Weather.RAIN or current == Weather.STORM else 1.0

func enemy_aggro_mult() -> float:
    return 0.85 if current == Weather.FOG else 1.0

func tint() -> Color:
    match current:
        Weather.CLEAR: return Color(1, 1, 1)
        Weather.RAIN: return Color(0.85, 0.85, 0.95)
        Weather.STORM: return Color(0.6, 0.6, 0.85)
        Weather.FOG: return Color(0.85, 0.9, 0.95)
        Weather.ASHFALL: return Color(1.05, 0.85, 0.7)
    return Color.WHITE
