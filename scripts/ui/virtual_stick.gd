extends Control

# Virtual stick for portrait-mobile combat. Spec: docs/ui_spec.md §6, §7.1.
# Compact bucket: base diameter 144 dp (radius 72), knob 56 dp.
# Center sits in the bottom-left thumb arc at (16+72, bottom-(16+72)).
# Anchored Control fills the screen so input handling can hit-test the
# whole left half; only the visual base + knob are drawn at the center.

const T := preload("res://scripts/ui/ui_tokens.gd")

var center: Vector2 = Vector2.ZERO
var pad_radius: float = 72.0       # 144 dp diameter / 2
var knob_radius: float = 28.0      # 56 dp diameter / 2
var active_finger: int = -1
var stick: Vector2 = Vector2.ZERO

func _ready() -> void:
    if not (OS.has_feature("mobile") or OS.has_feature("web")):
        visible = false
    set_process_input(true)
    if Engine.has_singleton("OrientationMgr"):
        OrientationMgr.bucket_changed.connect(_on_bucket_changed)
    _apply_bucket()

func _on_bucket_changed(_b) -> void:
    _apply_bucket()
    queue_redraw()

func _apply_bucket() -> void:
    # Spec §6: stick base 144/168/192 dp by bucket; knob constant 56 dp.
    if not Engine.has_singleton("OrientationMgr"):
        return
    match OrientationMgr.bucket:
        OrientationMgr.Bucket.MEDIUM:
            pad_radius = 84.0
        OrientationMgr.Bucket.EXPANDED:
            pad_radius = 96.0
        _:
            pad_radius = 72.0

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventScreenTouch:
        var e := event as InputEventScreenTouch
        if e.position.x < get_viewport_rect().size.x * 0.5:
            if e.pressed:
                active_finger = e.index
                center = e.position
                stick = Vector2.ZERO
                queue_redraw()
            elif e.index == active_finger:
                active_finger = -1
                stick = Vector2.ZERO
                _apply()
                queue_redraw()
    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if d.index == active_finger:
            stick = (d.position - center).limit_length(pad_radius)
            _apply()
            queue_redraw()

func _apply() -> void:
    var v: Vector2 = stick / pad_radius
    Input.action_release("move_up")
    Input.action_release("move_down")
    Input.action_release("move_left")
    Input.action_release("move_right")
    if v.x > 0.2: Input.action_press("move_right", v.x)
    elif v.x < -0.2: Input.action_press("move_left", -v.x)
    if v.y > 0.2: Input.action_press("move_down", v.y)
    elif v.y < -0.2: Input.action_press("move_up", -v.y)

func _draw() -> void:
    if not visible:
        return
    var resting_center: Vector2 = Vector2(16 + pad_radius, get_viewport_rect().size.y - 16 - pad_radius)
    var base_pos: Vector2 = resting_center if active_finger == -1 else center
    var knob_pos: Vector2 = base_pos + stick
    # Outer ring
    draw_arc(base_pos, pad_radius, 0.0, TAU, 64, Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, 0.40), 2.0, true)
    # Inner translucent fill
    draw_circle(base_pos, pad_radius, Color(T.SURFACE.r, T.SURFACE.g, T.SURFACE.b, 0.45))
    # Knob
    var knob_alpha: float = 0.85 if active_finger != -1 else 0.55
    draw_circle(knob_pos, knob_radius, Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, knob_alpha))
