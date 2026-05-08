extends Node

# 3D VFX library. Each public function spawns a short-lived effect node.
# Effects use object pooling + lifetime caps to honor Android perf budgets.

const POOL_LIMIT := 96

var _root: Node = null
var _spawn_count: int = 0
var _last_reset_t: float = 0.0

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

func _budget_ok() -> bool:
    var t: float = Time.get_ticks_msec() / 1000.0
    if t - _last_reset_t > 1.0:
        _last_reset_t = t
        _spawn_count = 0
    if _spawn_count >= POOL_LIMIT:
        return false
    _spawn_count += 1
    return true

func screen_shake(strength: float, duration: float = 0.18) -> void:
    EventBus.screen_shake.emit(strength * Settings.screen_shake_scale, duration)

func hit_stop(duration: float = 0.04) -> void:
    EventBus.hit_stop.emit(duration)

func floating_text(text: String, world_pos: Vector3, color: Color = Color.WHITE) -> void:
    EventBus.floating_text.emit(text, Vector2(world_pos.x, world_pos.z), color)

# 3D burst at a world position. Uses CPUParticles3D for reliability across
# the headless test path; can be swapped to GPUParticles3D in a polish pass.
func spawn_hit_burst_3d(pos: Vector3, color: Color = Color.WHITE, scale: float = 1.0) -> void:
    if not _budget_ok(): return
    var p := _make_burst(pos, color, 18, 6.0 * scale, 0.3, 3.0)
    _attach(p, 0.6)

func spawn_crit_burst_3d(pos: Vector3, color: Color = Color(1, 0.85, 0.2)) -> void:
    if not _budget_ok(): return
    var p := _make_burst(pos, color, 32, 10.0, 0.5, 4.5)
    _attach(p, 0.8)
    screen_shake(7.0, 0.18)

func spawn_death_burst_3d(pos: Vector3, color: Color = Color(0.95, 0.2, 0.2)) -> void:
    if not _budget_ok(): return
    var p := _make_burst(pos, color, 48, 12.0, 0.6, 5.0)
    _attach(p, 1.2)
    screen_shake(4.0, 0.15)

func spawn_levelup_flare_3d(pos: Vector3) -> void:
    var p := _make_burst(pos + Vector3.UP * 1.0, Color(1, 0.85, 0.4), 64, 16.0, 0.7, 6.0)
    _attach(p, 1.5)
    var l := OmniLight3D.new()
    l.position = pos + Vector3.UP * 1.5
    l.light_color = Color(1, 0.85, 0.45)
    l.light_energy = 4.0
    l.omni_range = 8.0
    var root := _ensure_root()
    if root != null:
        root.add_child(l)
        var tw := l.create_tween()
        tw.tween_property(l, "light_energy", 0.0, 0.8)
        tw.tween_callback(l.queue_free)

# Vertical light pillar for loot drops; rarity-colored.
func spawn_loot_pillar_3d(pos: Vector3, color: Color, height: float = 6.0) -> Node3D:
    var root := _ensure_root()
    if root == null:
        return null
    var pillar := Node3D.new()
    pillar.position = pos
    root.add_child(pillar)
    var beam := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.05
    cyl.bottom_radius = 0.18
    cyl.height = height
    cyl.radial_segments = 12
    beam.mesh = cyl
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 2.5
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam.material_override = mat
    beam.position.y = height * 0.5
    pillar.add_child(beam)
    var l := OmniLight3D.new()
    l.position = Vector3(0, 1.5, 0)
    l.light_color = color
    l.light_energy = 2.0
    l.omni_range = 5.0
    pillar.add_child(l)
    return pillar

func spawn_arc_3d(from: Vector3, to: Vector3) -> void:
    var root := _ensure_root()
    if root == null:
        return
    var line := MeshInstance3D.new()
    var im := ImmediateMesh.new()
    im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
    var mid := from.lerp(to, 0.5) + Vector3(randf_range(-0.4,0.4), randf_range(-0.2,0.6), randf_range(-0.4,0.4))
    im.surface_set_color(Color(0.5, 0.85, 1.0))
    im.surface_add_vertex(from + Vector3.UP)
    im.surface_add_vertex(mid + Vector3.UP)
    im.surface_add_vertex(to + Vector3.UP)
    im.surface_end()
    line.mesh = im
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.7, 0.9, 1, 1)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    line.material_override = mat
    root.add_child(line)
    var tw := line.create_tween()
    tw.tween_property(line, "modulate", Color(1,1,1,0), 0.15)
    tw.tween_callback(line.queue_free)

func spawn_fire_ring_3d(parent: Node3D, radius: float = 2.0) -> Node3D:
    var ring := Node3D.new()
    ring.name = "FireRing"
    parent.add_child(ring)
    for i in range(20):
        var ang := TAU * float(i) / 20.0
        var ember := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.10
        sm.height = 0.20
        ember.mesh = sm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(1.0, 0.45, 0.05, 1)
        mat.emission_enabled = true
        mat.emission = Color(1.0, 0.5, 0.05)
        mat.emission_energy_multiplier = 3.0
        ember.material_override = mat
        ember.position = Vector3(cos(ang) * radius, 0.3, sin(ang) * radius)
        ring.add_child(ember)
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.5, 0.2)
    l.light_energy = 1.8
    l.omni_range = radius * 2.0
    ring.add_child(l)
    return ring

# --- private helpers ---

func _make_burst(pos: Vector3, color: Color, count: int, speed: float, life: float, scale: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.position = pos
    p.amount = clamp(count, 4, 96)
    p.one_shot = true
    p.explosiveness = 0.85
    p.lifetime = life
    p.emitting = true
    p.gravity = Vector3(0, -2.0, 0)
    p.initial_velocity_min = speed * 0.6
    p.initial_velocity_max = speed
    p.spread = 180.0
    p.scale_amount_min = scale * 0.05
    p.scale_amount_max = scale * 0.10
    p.color = color
    p.direction = Vector3.UP
    return p

func _attach(particles: Node3D, lifespan: float) -> void:
    var root := _ensure_root()
    if root == null:
        return
    root.add_child(particles)
    var tree := get_tree()
    if tree == null:
        particles.queue_free()
        return
    await tree.create_timer(lifespan + 0.3).timeout
    if is_instance_valid(particles):
        particles.queue_free()
