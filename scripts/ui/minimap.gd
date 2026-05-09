extends Control

# Live radial minimap. Reads the active scene tree each frame and dots:
#   - player (gold) at center
#   - enemies (red)
#   - loot drops (gold dim)
#   - bosses (large ember)
# 30 m world radius maps to the minimap radius. Beyond that, dots clamp
# to the perimeter so the player still has a directional cue.

const T := preload("res://scripts/ui/ui_tokens.gd")

@export var world_radius: float = 30.0      # game-world meters that fit on the map

var _player_cache: Node3D = null
var _player_search_t: float = 0.0

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    _player_search_t -= delta
    if _player_cache == null or not is_instance_valid(_player_cache):
        if _player_search_t <= 0.0:
            _player_search_t = 0.5
            var arr := get_tree().get_nodes_in_group("player")
            _player_cache = arr[0] if not arr.is_empty() else null
    queue_redraw()

func _draw() -> void:
    var s: Vector2 = size
    var center: Vector2 = s * 0.5
    var radius: float = min(s.x, s.y) * 0.5 - 2.0

    # Backdrop
    draw_circle(center, radius, Color(T.SURFACE.r, T.SURFACE.g, T.SURFACE.b, 0.85))
    draw_arc(center, radius, 0.0, TAU, 64, Color(T.OUTLINE_VARIANT.r, T.OUTLINE_VARIANT.g, T.OUTLINE_VARIANT.b, 0.9), 1.5, true)
    # Cardinal compass tick (north)
    draw_line(center + Vector2(0, -radius + 1), center + Vector2(0, -radius + 6), T.PRIMARY, 1.5)

    if _player_cache == null:
        return
    var ppos: Vector3 = _player_cache.global_position

    # Sweep arc — slow rotating "scan line" for ambience
    var sweep_a: float = fmod(Time.get_ticks_msec() / 1500.0, TAU)
    draw_arc(center, radius * 0.96, sweep_a, sweep_a + 0.45, 24,
        Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, 0.20), 4.0, true)

    # Player dot at center
    draw_circle(center, 4.0, T.PRIMARY)

    # Enemies (red dots)
    for e in get_tree().get_nodes_in_group("enemy"):
        if not (e is Node3D) or not is_instance_valid(e):
            continue
        _plot_dot(center, radius, ppos, (e as Node3D).global_position, T.ERROR, 3.0)

    # Bosses (larger ember dot)
    for b in get_tree().get_nodes_in_group("boss"):
        if not (b is Node3D) or not is_instance_valid(b):
            continue
        _plot_dot(center, radius, ppos, (b as Node3D).global_position, T.SECONDARY, 6.0)

    # Loot (gold dim dots)
    for l in get_tree().get_nodes_in_group("loot"):
        if not (l is Node3D) or not is_instance_valid(l):
            continue
        var col := Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, 0.65)
        _plot_dot(center, radius, ppos, (l as Node3D).global_position, col, 2.0)

func _plot_dot(center: Vector2, radius: float, ppos: Vector3, target: Vector3, col: Color, dot_radius: float) -> void:
    var d2: Vector2 = Vector2(target.x - ppos.x, target.z - ppos.z)
    var dist: float = d2.length()
    if dist < 0.001:
        return
    var t: float = clamp(dist / world_radius, 0.0, 1.0)
    var pos: Vector2 = center + d2.normalized() * radius * t
    draw_circle(pos, dot_radius, col)
