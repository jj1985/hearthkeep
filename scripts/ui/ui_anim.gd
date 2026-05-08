extends RefCounted
class_name UiAnim

# M3-derived motion tokens + reusable animations.
# Spec: docs/ui_spec.md §12.

# ---- Duration tokens (ms → seconds) ----
const DUR_XS := 0.10    # tooltip show, color tint
const DUR_SM := 0.18    # button press, chip select
const DUR_MD := 0.24    # card lift, modal open
const DUR_LG := 0.32    # screen transition, perk-pick total stagger
const DUR_XL := 0.48    # cinematic camera dolly

# ---- Easing primitives (Godot equivalents of M3 curves) ----
# Standard:        TRANS_CUBIC, EASE_OUT
# Emphasized in:   TRANS_BACK,  EASE_OUT  (cards arriving, menus sliding up)
# Emphasized out:  TRANS_CUBIC, EASE_IN   (cards leaving)

# ---- Button press feedback (spec §12.2) ----
# Two-phase: scale 1.0 → 0.97 in DUR_SM, snap back over DUR_SM, no Material ripple.
static func bind_press_feedback(b: Control, target_scale: float = 0.97) -> void:
    b.button_down.connect(func(): _press_in(b, target_scale))
    b.button_up.connect(func(): _press_out(b))
    b.mouse_exited.connect(func(): _press_out(b))

static func _press_in(b: Control, target_scale: float) -> void:
    b.pivot_offset = b.size * 0.5
    var tw: Tween = b.create_tween()
    tw.tween_property(b, "scale", Vector2(target_scale, target_scale), DUR_SM
        ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func _press_out(b: Control) -> void:
    var tw: Tween = b.create_tween()
    tw.tween_property(b, "scale", Vector2.ONE, DUR_SM
        ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ---- Modal / sheet open animation (slide up + fade) ----
static func slide_up_in(c: Control, distance: float = 80.0, dur: float = DUR_LG) -> void:
    c.modulate.a = 0.0
    c.position.y += distance
    var tw := c.create_tween().set_parallel(true)
    tw.tween_property(c, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(c, "position:y", c.position.y - distance, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---- Cross-fade between two siblings (e.g. screen transition) ----
static func crossfade(out_node: Control, in_node: Control, dur: float = DUR_LG) -> void:
    in_node.modulate.a = 0.0
    in_node.visible = true
    var tw := in_node.create_tween().set_parallel(true)
    tw.tween_property(out_node, "modulate:a", 0.0, dur)
    tw.tween_property(in_node, "modulate:a", 1.0, dur)
    await tw.finished
    out_node.visible = false

# ---- Pulse a node (e.g. tap-to-begin label, low-HP warning) ----
static func pulse(c: CanvasItem, period: float, low: float, high: float) -> Tween:
    var tw: Tween = c.create_tween().set_loops()
    tw.tween_property(c, "modulate:a", high, period * 0.5)
    tw.tween_property(c, "modulate:a", low, period * 0.5)
    return tw
