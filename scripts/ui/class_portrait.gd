extends Control

# Procedural class portrait. Draws a stylized silhouette + accent + emboss
# vignette per class. Holds the slot until real CC0 art lands; spec §8.4
# notes the swap path leaves UI structure untouched.

const T := preload("res://scripts/ui/ui_tokens.gd")

@export var class_id: String = "warrior":
    set(value):
        class_id = value
        queue_redraw()

func _ready() -> void:
    set_process(true)

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var s: Vector2 = size
    if s.x < 4.0 or s.y < 4.0:
        return
    var center: Vector2 = s * 0.5
    var radius: float = min(s.x, s.y) * 0.46

    # Backdrop disc — class-tinted
    var tint: Color = _tint_for(class_id)
    draw_circle(center, radius, Color(tint.r * 0.4, tint.g * 0.4, tint.b * 0.45, 1.0))

    # Soft inner glow ring
    draw_arc(center, radius * 0.97, 0.0, TAU, 64,
        Color(tint.r, tint.g, tint.b, 0.45), 6.0, true)

    # Silhouette
    _draw_silhouette(center, radius, class_id)

    # Gold edge-light arc (top-left highlight, simulating a single light source)
    var pulse: float = 0.6 + 0.2 * sin(Time.get_ticks_msec() * 0.0015)
    draw_arc(center, radius - 1.5, deg_to_rad(170.0), deg_to_rad(290.0), 24,
        Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, pulse), 2.0, true)

    # Vignette ring (drop-shadow inside the disc edge)
    draw_arc(center, radius - 0.5, 0.0, TAU, 64,
        Color(0, 0, 0, 0.55), 1.5, true)

func _tint_for(id: String) -> Color:
    match id:
        "warrior":     return Color("#7C5C3D")
        "rogue":       return Color("#3D3A4A")
        "wizard":      return Color("#3D5A7C")
        "necromancer": return Color("#3D2D3D")
        "bard":        return Color("#7C5A3D")
        "paladin":     return Color("#9A7C3D")
        "ranger":      return Color("#3D5A3D")
    return T.SURFACE_OVERLAY

# Stylized vector silhouettes — head + torso + class accent, drawn with
# polygons + lines so they remain crisp at any scale.
func _draw_silhouette(c: Vector2, r: float, id: String) -> void:
    # Common humanoid body
    var ink := Color(0.06, 0.05, 0.08, 1)
    # Head (circle)
    draw_circle(c + Vector2(0, -r * 0.50), r * 0.18, ink)
    # Torso (trapezoid)
    var torso := PackedVector2Array([
        c + Vector2(-r * 0.28, -r * 0.30),
        c + Vector2( r * 0.28, -r * 0.30),
        c + Vector2( r * 0.18,  r * 0.20),
        c + Vector2(-r * 0.18,  r * 0.20),
    ])
    draw_polygon(torso, [ink])

    var accent: Color = _accent_for(id)
    match id:
        "warrior":
            # Sword over shoulder
            draw_line(c + Vector2(r * 0.30, -r * 0.55), c + Vector2(-r * 0.20, r * 0.10), accent, 4.0)
            draw_line(c + Vector2(r * 0.18, -r * 0.40), c + Vector2(r * 0.42, -r * 0.40), accent, 3.0)
        "rogue":
            # Hood (triangle over head)
            var hood := PackedVector2Array([
                c + Vector2(-r * 0.30, -r * 0.40),
                c + Vector2( r * 0.30, -r * 0.40),
                c + Vector2(0, -r * 0.78),
            ])
            draw_polygon(hood, [Color(0.10, 0.09, 0.13, 1)])
            # Two daggers crossed
            draw_line(c + Vector2(-r * 0.30, r * 0.05), c + Vector2(r * 0.10, r * 0.30), accent, 2.5)
            draw_line(c + Vector2( r * 0.30, r * 0.05), c + Vector2(-r * 0.10, r * 0.30), accent, 2.5)
        "wizard":
            # Tall pointed hat
            var hat := PackedVector2Array([
                c + Vector2(-r * 0.28, -r * 0.42),
                c + Vector2( r * 0.28, -r * 0.42),
                c + Vector2( r * 0.05, -r * 0.92),
            ])
            draw_polygon(hat, [Color(0.10, 0.13, 0.20, 1)])
            # Star at hat tip
            draw_circle(c + Vector2(r * 0.05, -r * 0.92), r * 0.05, accent)
            # Staff
            draw_line(c + Vector2(r * 0.32, -r * 0.30), c + Vector2(r * 0.40, r * 0.40), Color(0.18, 0.14, 0.10, 1), 3.0)
            draw_circle(c + Vector2(r * 0.32, -r * 0.32), r * 0.08, accent)
        "necromancer":
            # Skull cowl
            draw_circle(c + Vector2(0, -r * 0.50), r * 0.20, Color(0.95, 0.92, 0.85, 1))
            draw_circle(c + Vector2(-r * 0.06, -r * 0.50), r * 0.04, ink)
            draw_circle(c + Vector2( r * 0.06, -r * 0.50), r * 0.04, ink)
            # Wraith aura wisps
            for i in range(5):
                var ang: float = deg_to_rad(180.0 + i * 36.0)
                var p1 := c + Vector2(cos(ang), sin(ang)) * r * 0.55
                var p2 := c + Vector2(cos(ang), sin(ang)) * r * 0.78
                draw_line(p1, p2, Color(accent.r, accent.g, accent.b, 0.7), 1.5)
        "bard":
            # Lute over body
            draw_circle(c + Vector2(-r * 0.10, r * 0.05), r * 0.18, accent)
            draw_line(c + Vector2(-r * 0.10, r * 0.05), c + Vector2(r * 0.40, -r * 0.40), Color(0.30, 0.20, 0.10, 1), 3.0)
            # Three string lines on the lute body
            for i in range(3):
                draw_line(c + Vector2(-r * 0.20, r * 0.00 + i * r * 0.04),
                          c + Vector2(r * 0.10, -r * 0.10 + i * r * 0.04),
                          Color(0.95, 0.85, 0.4, 0.9), 1.0)
        "paladin":
            # Cross / Tau symbol on chest
            draw_line(c + Vector2(0, -r * 0.20), c + Vector2(0, r * 0.18), accent, 4.0)
            draw_line(c + Vector2(-r * 0.10, -r * 0.05), c + Vector2(r * 0.10, -r * 0.05), accent, 4.0)
            # Halo
            draw_arc(c + Vector2(0, -r * 0.55), r * 0.22, deg_to_rad(180.0), deg_to_rad(360.0), 24,
                Color(accent.r, accent.g, accent.b, 0.85), 2.0, true)
        "ranger":
            # Bow arc
            draw_arc(c + Vector2(r * 0.30, 0), r * 0.45, deg_to_rad(-100.0), deg_to_rad(100.0), 32,
                accent, 2.5, true)
            # String
            draw_line(c + Vector2(r * 0.30, -r * 0.43), c + Vector2(r * 0.30, r * 0.43), Color(0.85, 0.75, 0.55, 1), 1.0)
            # Quiver feathers
            draw_line(c + Vector2(-r * 0.25, -r * 0.45), c + Vector2(-r * 0.10, -r * 0.20), accent, 2.0)
            draw_line(c + Vector2(-r * 0.18, -r * 0.50), c + Vector2(-r * 0.05, -r * 0.20), accent, 2.0)

func _accent_for(id: String) -> Color:
    match id:
        "warrior":     return Color(0.85, 0.80, 0.70)        # steel grey-gold
        "rogue":       return Color(0.55, 0.55, 0.65)        # cool steel
        "wizard":      return Color(0.50, 0.70, 1.00)        # rune-blue
        "necromancer": return Color(0.70, 0.45, 0.85)        # wraith violet
        "bard":        return Color(0.85, 0.55, 0.30)        # ember
        "paladin":     return Color(1.00, 0.85, 0.40)        # gold
        "ranger":      return Color(0.55, 0.80, 0.45)        # verdant
    return Color.WHITE
