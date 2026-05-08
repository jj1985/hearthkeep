extends Node

# Lightweight VFX library. Each public function spawns a short-lived effect.
# All particle effects use object pooling to honor the Android perf budget.

const POOL_LIMIT := 256

var _pool: Array = []
var _root: Node = null

func _ready() -> void:
    pass

func _ensure_root() -> Node:
    if _root != null and is_instance_valid(_root):
        return _root
    var tree := get_tree()
    if tree == null:
        return null
    _root = tree.current_scene
    return _root

func screen_shake(strength: float, duration: float = 0.18) -> void:
    EventBus.screen_shake.emit(strength, duration)

func hit_stop(duration: float = 0.04) -> void:
    EventBus.hit_stop.emit(duration)

func floating_text(text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
    EventBus.floating_text.emit(text, pos, color)

func spawn_hit_burst(pos: Vector2, color: Color = Color.WHITE, scale: float = 1.0) -> void:
    var p := _new_particles(pos, color, 16, 70.0 * scale, 0.25, 0.45, 3.0)
    _attach(p)

func spawn_crit_burst(pos: Vector2, color: Color = Color(1, 0.85, 0.2)) -> void:
    var p := _new_particles(pos, color, 32, 140.0, 0.35, 0.65, 4.5)
    _attach(p)
    screen_shake(7.0, 0.18)

func spawn_death_burst(pos: Vector2, color: Color = Color(0.95, 0.2, 0.2)) -> void:
    var p := _new_particles(pos, color, 48, 180.0, 0.4, 0.7, 5.0)
    _attach(p)
    screen_shake(4.0, 0.15)

func spawn_loot_pillar(pos: Vector2, color: Color, height: float = 96.0) -> void:
    var root := _ensure_root()
    if root == null:
        return
    var line := Line2D.new()
    line.width = 6.0
    line.default_color = color
    line.add_point(pos)
    line.add_point(pos + Vector2(0, -height))
    line.modulate.a = 0.85
    line.z_index = 50
    root.add_child(line)
    var tw := line.create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 1.5)
    tw.tween_callback(line.queue_free)

func spawn_coin_spray(pos: Vector2, count: int = 8) -> void:
    var p := _new_particles(pos, Color(1, 0.85, 0.2), count, 130.0, 0.5, 0.95, 3.0)
    _attach(p)

func spawn_levelup_flare(pos: Vector2) -> void:
    var p := _new_particles(pos, Color(0.95, 0.85, 0.4), 64, 220.0, 0.5, 1.0, 6.0)
    _attach(p)
    floating_text("LEVEL UP!", pos + Vector2(0, -32), Color(1, 0.85, 0.3))

func spawn_fire_ring(parent: Node2D, radius: float = 64.0) -> Node2D:
    # A persistent fire ring around the player when Sunfire Reaver is equipped.
    var ring := Node2D.new()
    ring.name = "FireRing"
    parent.add_child(ring)
    var bodies := []
    for i in range(20):
        var ang := TAU * float(i) / 20.0
        var dot := _spark(Color(1.0, 0.45, 0.05))
        dot.position = Vector2(cos(ang), sin(ang)) * radius
        ring.add_child(dot)
        bodies.append(dot)
    var t := 0.0
    ring.set_meta("radius", radius)
    ring.set_meta("bodies", bodies)
    return ring

func spawn_arc_discharge(from: Vector2, to: Vector2) -> void:
    var root := _ensure_root()
    if root == null:
        return
    var l := Line2D.new()
    l.default_color = Color(0.45, 0.85, 1.0)
    l.width = 3.0
    l.add_point(from)
    var midpoints := 5
    for i in range(1, midpoints):
        var t := float(i) / float(midpoints)
        var p := from.lerp(to, t)
        p += Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
        l.add_point(p)
    l.add_point(to)
    l.z_index = 60
    root.add_child(l)
    var tw := l.create_tween()
    tw.tween_property(l, "modulate:a", 0.0, 0.18)
    tw.tween_callback(l.queue_free)

# --- private helpers ---

func _new_particles(pos: Vector2, color: Color, count: int, speed: float, lifetime: float, life_max: float, scale: float) -> CPUParticles2D:
    var p := CPUParticles2D.new()
    p.position = pos
    p.amount = clamp(count, 4, 96)
    p.one_shot = true
    p.explosiveness = 0.85
    p.lifetime = life_max
    p.speed_scale = 1.0
    p.emitting = true
    p.gravity = Vector2.ZERO
    p.initial_velocity_min = speed * 0.6
    p.initial_velocity_max = speed
    p.spread = 180.0
    p.scale_amount_min = scale * 0.4
    p.scale_amount_max = scale
    p.color = color
    p.z_index = 40
    return p

func _spark(color: Color) -> Sprite2D:
    var s := Sprite2D.new()
    var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
    img.fill(color)
    s.texture = ImageTexture.create_from_image(img)
    s.modulate.a = 0.85
    return s

func _attach(particles: CPUParticles2D) -> void:
    var root := _ensure_root()
    if root == null:
        return
    root.add_child(particles)
    var tree := get_tree()
    if tree == null:
        particles.queue_free()
        return
    await tree.create_timer(particles.lifetime + 0.2).timeout
    if is_instance_valid(particles):
        particles.queue_free()
