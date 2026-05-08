extends Control

# Lightweight virtual stick for mobile. Touch-and-drag in lower-left
# overrides keyboard movement axes. Right-side: skill buttons (4) + dodge.

var center: Vector2 = Vector2.ZERO
var pad_radius: float = 80.0
var active_finger: int = -1
var stick: Vector2 = Vector2.ZERO

func _ready() -> void:
    if not (OS.has_feature("mobile") or OS.has_feature("web")):
        visible = false
    set_process_input(true)

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
            elif e.index == active_finger:
                active_finger = -1
                stick = Vector2.ZERO
                _apply()
    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if d.index == active_finger:
            stick = (d.position - center).limit_length(pad_radius)
            _apply()

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
    if not visible: return
    if active_finger == -1:
        var p: Vector2 = Vector2(120, get_viewport_rect().size.y - 120)
        draw_circle(p, pad_radius, Color(1,1,1,0.10))
    else:
        draw_circle(center, pad_radius, Color(1,1,1,0.10))
        draw_circle(center + stick, pad_radius * 0.4, Color(1,1,1,0.40))
