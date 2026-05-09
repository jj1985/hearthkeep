extends CanvasLayer

# Pooled floating-text renderer. Subscribes to EventBus.floating_text and
# spawns labels at projected screen positions. Spec: docs/ui_spec.md §7.4.
#
# Conventions for the floating_text signal Vector2 payload:
#   Vector2.ZERO        → render centered above HUD (e.g. "LEVEL UP")
#   Vector2(x, z)       → world-space coords on the y=0 ground plane;
#                         we project via the active Camera3D.
#
# Color drives the variant: red → damage shake, gold→ levelup glow, ember
# → crit pop. Magnitude is implicit in the caller's text styling.

const T := preload("res://scripts/ui/ui_tokens.gd")

const POOL_SIZE := 32

var _labels: Array[Label] = []
var _free: Array[int] = []

func _ready() -> void:
    layer = 100    # above HUD
    for i in range(POOL_SIZE):
        var l := Label.new()
        l.add_theme_font_size_override("font_size", T.FS_NUMERIC_MD)
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.visible = false
        l.set_anchors_preset(Control.PRESET_TOP_LEFT)
        add_child(l)
        _labels.append(l)
        _free.append(i)
    EventBus.floating_text.connect(_on_floating_text)

func _on_floating_text(text: String, world_pos: Vector2, color: Color) -> void:
    if _free.is_empty():
        return
    var idx: int = _free.pop_back()
    var l: Label = _labels[idx]
    l.text = text
    l.add_theme_color_override("font_color", color)
    var screen_pos: Vector2 = _project(world_pos)
    l.size = Vector2.ZERO
    l.position = screen_pos
    l.modulate.a = 1.0
    l.scale = Vector2.ONE
    l.visible = true

    var is_crit: bool = abs(color.r - T.SECONDARY.r) < 0.05 and abs(color.g - T.SECONDARY.g) < 0.1
    var is_error: bool = abs(color.r - T.ERROR.r) < 0.05 and color.r > 0.5
    var is_levelup: bool = abs(color.r - T.PRIMARY.r) < 0.05 and color.g > 0.6

    if is_crit:
        l.add_theme_font_size_override("font_size", T.FS_NUMERIC_LG)
        var pop := create_tween().set_parallel(true)
        pop.tween_property(l, "scale", Vector2(1.4, 1.4), 0.12).set_ease(Tween.EASE_OUT)
        pop.chain().tween_property(l, "scale", Vector2.ONE, 0.13)
    else:
        l.add_theme_font_size_override("font_size", T.FS_NUMERIC_MD if not is_levelup else T.FS_HEADLINE_SM)

    var rise: float = 60.0 if not is_crit else 80.0
    var dur: float = 0.7 if not is_crit else 0.9
    var x_shake: float = 6.0 if is_error else 0.0

    var tw := create_tween().set_parallel(true)
    if x_shake > 0.0:
        tw.tween_property(l, "position:x", screen_pos.x + x_shake, 0.06)
        tw.chain().tween_property(l, "position:x", screen_pos.x - x_shake, 0.06)
        tw.chain().tween_property(l, "position:x", screen_pos.x, 0.04)
    tw.tween_property(l, "position:y", screen_pos.y - rise, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var fade := dur * 0.45
    tw.chain().tween_property(l, "modulate:a", 0.0, fade)
    tw.chain().tween_callback(func():
        l.visible = false
        _free.append(idx))

func _project(world_pos: Vector2) -> Vector2:
    if world_pos == Vector2.ZERO:
        var vs: Vector2 = get_viewport().get_visible_rect().size
        return Vector2(vs.x * 0.5 - 60.0, vs.y * 0.32)
    var camera: Camera3D = get_viewport().get_camera_3d()
    if camera == null:
        var vs2: Vector2 = get_viewport().get_visible_rect().size
        return vs2 * 0.5
    var p3: Vector3 = Vector3(world_pos.x, 1.0, world_pos.y)
    return camera.unproject_position(p3)
