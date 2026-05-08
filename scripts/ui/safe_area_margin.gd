@tool
extends MarginContainer

# Wraps fullscreen UI chrome inside the device safe area (status bar,
# punch-hole cutout, gesture nav strip). Spec: docs/ui_spec.md §2.2.
#
# Usage: drop a SafeAreaMargin between your screen root Control and your
# real UI. Optionally set extra_padding_dp for additional design padding
# on top of the system insets (e.g. perk overlay uses +16, combat HUD
# bottom buttons use +24).

@export var extra_padding_dp: int = 0

func _ready() -> void:
    if not Engine.is_editor_hint():
        OrientationMgr.safe_area_changed.connect(_apply)
        var root := get_tree().root
        if root != null:
            root.size_changed.connect(_apply.bind(OrientationMgr.safe_area))
    _apply(OrientationMgr.safe_area if Engine.has_singleton("OrientationMgr") else Rect2i())

func _apply(sa: Rect2i) -> void:
    var win: Vector2i = DisplayServer.window_get_size()
    var vp: Vector2 = get_viewport_rect().size
    if vp.x <= 0.0 or vp.y <= 0.0:
        return
    var sx: float = 1.0
    var sy: float = 1.0
    if win.x > 0 and win.y > 0:
        sx = vp.x / float(win.x)
        sy = vp.y / float(win.y)
    var l: int = int(max(0, sa.position.x) * sx) + extra_padding_dp
    var t: int = int(max(0, sa.position.y) * sy) + extra_padding_dp
    var r: int = int(max(0, win.x - sa.position.x - sa.size.x) * sx) + extra_padding_dp
    var b: int = int(max(0, win.y - sa.position.y - sa.size.y) * sy) + extra_padding_dp
    add_theme_constant_override("margin_left", l)
    add_theme_constant_override("margin_top", t)
    add_theme_constant_override("margin_right", r)
    add_theme_constant_override("margin_bottom", b)
