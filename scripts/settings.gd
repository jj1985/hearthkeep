extends Node

# Player settings: control scheme, orientation lock, accessibility.

enum ControlScheme { TWIN_STICK, TAP_TO_MOVE_AUTO_ATTACK }
enum HandedMode { RIGHT, LEFT }
enum CameraMode { FIXED_ISO, DYNAMIC_LOOKAHEAD }

var control_scheme: int = ControlScheme.TWIN_STICK
var handed_mode: int = HandedMode.RIGHT
var camera_mode: int = CameraMode.DYNAMIC_LOOKAHEAD
var auto_pickup_junk: bool = true
var auto_sell_junk: bool = false
var run_end_auto_return: bool = true
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var voice_volume: float = 0.9
var ambient_volume: float = 0.6
var screen_shake_scale: float = 1.0
var subtitle_barks: bool = true
var orientation_lock: String = "auto"   # auto | landscape | portrait
var haptics: bool = true
var tutorial_seen: bool = false

const PATH := "user://aerathis_settings.json"

func save() -> void:
    var f := FileAccess.open(PATH, FileAccess.WRITE)
    if f == null: return
    f.store_string(JSON.stringify({
        "control_scheme": control_scheme,
        "handed_mode": handed_mode,
        "camera_mode": camera_mode,
        "auto_pickup_junk": auto_pickup_junk,
        "auto_sell_junk": auto_sell_junk,
        "run_end_auto_return": run_end_auto_return,
        "music_volume": music_volume,
        "sfx_volume": sfx_volume,
        "voice_volume": voice_volume,
        "ambient_volume": ambient_volume,
        "screen_shake_scale": screen_shake_scale,
        "subtitle_barks": subtitle_barks,
        "orientation_lock": orientation_lock,
        "haptics": haptics,
        "tutorial_seen": tutorial_seen,
    }))

func load_settings() -> void:
    if not FileAccess.file_exists(PATH): return
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f == null: return
    var d: Variant = JSON.parse_string(f.get_as_text())
    if typeof(d) != TYPE_DICTIONARY: return
    control_scheme = int((d as Dictionary).get("control_scheme", control_scheme))
    handed_mode = int((d as Dictionary).get("handed_mode", handed_mode))
    camera_mode = int((d as Dictionary).get("camera_mode", camera_mode))
    auto_pickup_junk = bool((d as Dictionary).get("auto_pickup_junk", auto_pickup_junk))
    auto_sell_junk = bool((d as Dictionary).get("auto_sell_junk", auto_sell_junk))
    run_end_auto_return = bool((d as Dictionary).get("run_end_auto_return", run_end_auto_return))
    music_volume = float((d as Dictionary).get("music_volume", music_volume))
    sfx_volume = float((d as Dictionary).get("sfx_volume", sfx_volume))
    voice_volume = float((d as Dictionary).get("voice_volume", voice_volume))
    ambient_volume = float((d as Dictionary).get("ambient_volume", ambient_volume))
    screen_shake_scale = float((d as Dictionary).get("screen_shake_scale", screen_shake_scale))
    subtitle_barks = bool((d as Dictionary).get("subtitle_barks", subtitle_barks))
    orientation_lock = str((d as Dictionary).get("orientation_lock", orientation_lock))
    haptics = bool((d as Dictionary).get("haptics", haptics))
    tutorial_seen = bool((d as Dictionary).get("tutorial_seen", tutorial_seen))

func _ready() -> void:
    load_settings()
