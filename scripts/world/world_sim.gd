extends Node

# World simulation: clock, day/night phases, NPC schedule ticks.
# Pauses during runs; ticks slowly in background. One in-game day = 20 real
# minutes of UNPAUSED hub time (configurable).

enum Phase { DAWN, DAY, DUSK, NIGHT }

const REAL_SECONDS_PER_DAY := 1200.0    # 20 minutes
const PHASE_BOUNDS := {
    Phase.DAWN: [5.0, 8.0],
    Phase.DAY: [8.0, 18.0],
    Phase.DUSK: [18.0, 21.0],
    Phase.NIGHT: [21.0, 29.0],   # wraps; 24+5
}

var hour: float = 8.0
var day: int = 1
var phase: int = Phase.DAY
var paused_for_run: bool = false
var background_rate: float = 0.10        # tick rate while in run (0..1)

func _ready() -> void:
    set_process(true)
    EventBus.player_died.connect(_on_run_ended)

func _process(delta: float) -> void:
    var rate := 24.0 / REAL_SECONDS_PER_DAY
    if paused_for_run:
        rate *= background_rate
    var prev_phase := phase
    hour += delta * rate
    while hour >= 24.0:
        hour -= 24.0
        day += 1
    var p := _compute_phase(hour)
    if p != phase:
        phase = p
        EventBus.day_night_phase_changed.emit(phase)
    EventBus.hour_advanced.emit(hour)

func _compute_phase(h: float) -> int:
    if h >= 5.0 and h < 8.0: return Phase.DAWN
    if h >= 8.0 and h < 18.0: return Phase.DAY
    if h >= 18.0 and h < 21.0: return Phase.DUSK
    return Phase.NIGHT

func enter_run() -> void:
    paused_for_run = true

func exit_run() -> void:
    paused_for_run = false

func _on_run_ended() -> void:
    paused_for_run = false

func phase_color() -> Color:
    match phase:
        Phase.DAWN: return Color(1.05, 0.85, 0.7)
        Phase.DAY: return Color(1.0, 1.0, 1.0)
        Phase.DUSK: return Color(1.0, 0.7, 0.5)
        Phase.NIGHT: return Color(0.55, 0.6, 0.85)
    return Color.WHITE

func current_phase_name() -> String:
    return ["dawn","day","dusk","night"][phase]
