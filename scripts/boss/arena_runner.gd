extends Node3D

# Vyxhasis arena runner. Builds a cylindrical stone arena, brazier lights,
# spawns the player + Vyxhasis, drives camera tracking. Phase A only —
# no breath cones, no telegraph rings, no air-phase mesh swap. Future
# work in Phase B.

const PlayerScene := preload("res://scenes/player/player.tscn")
const VyxhasisScript := preload("res://scripts/entities/vyxhasis.gd")
const LootScene := preload("res://scenes/fx/loot_drop.tscn")

@onready var world: Node3D = $World
@onready var hud: CanvasLayer = $HUD

var player: Node3D
var dragon: Node3D
var camera: Camera3D
var camera_shake_t: float = 0.0
var camera_shake_strength: float = 0.0

func _ready() -> void:
    SaveSystem.load_save()
    Settings.load_settings()
    BuffSystem.clear_run_buffs()
    Inventory.reset_for_run()
    EventBus.loot_dropped.connect(_on_loot_dropped)
    EventBus.screen_shake.connect(_on_screen_shake)
    EventBus.hit_stop.connect(_on_hit_stop)
    _build_arena()
    _spawn_camera()
    _spawn_player()
    _spawn_dragon()
    MusicDirector.set_layer(MusicDirector.Layer.BOSS)
    SfxBus.play("dragon_roar", -2.0)
    EventBus.floating_text.emit("VYXHASIS  THE  CINDERWASTES", Vector3.ZERO, Color(1, 0.5, 0.3))

func _build_arena() -> void:
    # Cylindrical stone floor
    var floor_mesh := CSGCylinder3D.new()
    floor_mesh.radius = 22.0
    floor_mesh.height = 1.0
    floor_mesh.sides = 64
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.18, 0.14, 0.12)
    floor_mat.roughness = 0.85
    floor_mesh.material = floor_mat
    floor_mesh.position = Vector3(0, -0.5, 0)
    world.add_child(floor_mesh)

    # Sun (fading dusk)
    var sun := DirectionalLight3D.new()
    sun.light_color = Color(1.0, 0.45, 0.20)
    sun.light_energy = 0.6
    sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
    world.add_child(sun)

    # Ambient violet rim
    var amb := DirectionalLight3D.new()
    amb.light_color = Color(0.35, 0.22, 0.55)
    amb.light_energy = 0.25
    amb.rotation = Vector3(deg_to_rad(40), deg_to_rad(150), 0)
    world.add_child(amb)

    # Brazier lights at compass points
    var positions := [Vector3(0, 2.5, -16), Vector3(0, 2.5, 16),
                      Vector3(16, 2.5, 0), Vector3(-16, 2.5, 0)]
    for p in positions:
        var br := OmniLight3D.new()
        br.light_color = Color(1.0, 0.5, 0.2)
        br.light_energy = 4.0
        br.omni_range = 14.0
        br.position = p
        world.add_child(br)
        # Visible brazier mesh
        var brazier := CSGCylinder3D.new()
        brazier.radius = 0.6
        brazier.height = 2.0
        brazier.sides = 12
        var b_mat := StandardMaterial3D.new()
        b_mat.albedo_color = Color(0.18, 0.12, 0.08)
        b_mat.emission = Color(1.0, 0.4, 0.1)
        b_mat.emission_energy_multiplier = 1.0
        brazier.material = b_mat
        brazier.position = p - Vector3(0, 1.5, 0)
        world.add_child(brazier)

    # Background sky-dome backdrop
    var sky := Environment.new()
    sky.background_mode = Environment.BG_COLOR
    sky.background_color = Color(0.06, 0.04, 0.08)
    sky.fog_enabled = true
    sky.fog_light_color = Color(0.3, 0.15, 0.10)
    sky.fog_density = 0.015
    var world_env := WorldEnvironment.new()
    world_env.environment = sky
    world.add_child(world_env)

func _spawn_camera() -> void:
    camera = Camera3D.new()
    camera.fov = 52.0
    camera.position = Vector3(8, 12, 8)
    world.add_child(camera)

func _spawn_player() -> void:
    player = PlayerScene.instantiate()
    player.class_primary = RunState.class_primary
    player.class_secondary = RunState.class_secondary
    player.position = Vector3(0, 0, 8)
    world.add_child(player)

func _spawn_dragon() -> void:
    dragon = Node3D.new()
    dragon.set_script(VyxhasisScript)
    dragon.position = Vector3(0, 1.5, -8)
    # Build the body mesh as a child node
    var body := MeshInstance3D.new()
    body.name = "Body"
    var bm := BoxMesh.new()
    bm.size = Vector3(4, 3, 6)
    body.mesh = bm
    var dm := StandardMaterial3D.new()
    dm.albedo_color = Color("#5C2A1A")
    dm.emission_enabled = true
    body.set_surface_override_material(0, dm)
    dragon.add_child(body)
    # Hit area
    var area := Area3D.new()
    area.name = "HitArea"
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(4, 3, 6)
    shape.shape = box
    area.add_child(shape)
    dragon.add_child(area)
    world.add_child(dragon)

func _process(delta: float) -> void:
    if camera_shake_t > 0.0:
        camera_shake_t = max(0.0, camera_shake_t - delta)
        camera.h_offset = randf_range(-camera_shake_strength, camera_shake_strength) * 0.04
        camera.v_offset = randf_range(-camera_shake_strength, camera_shake_strength) * 0.04
        if camera_shake_t == 0.0:
            camera.h_offset = 0.0
            camera.v_offset = 0.0
    if player != null and is_instance_valid(player):
        var lookat: Vector3 = player.global_position
        var cam_target: Vector3 = lookat + Vector3(8.0, 12.0, 8.0)
        camera.position = camera.position.lerp(cam_target, 0.07)
        camera.look_at(lookat + Vector3.UP, Vector3.UP)

func _on_loot_dropped(item: Dictionary, pos: Variant) -> void:
    var l = LootScene.instantiate()
    if pos is Vector2:
        l.position = Vector3(pos.x, 0, pos.y)
    elif pos is Vector3:
        l.position = pos
    l.item = item
    world.add_child(l)

func _on_screen_shake(strength: float, duration: float) -> void:
    camera_shake_strength = max(camera_shake_strength, strength)
    camera_shake_t = max(camera_shake_t, duration)

func _on_hit_stop(duration: float) -> void:
    Engine.time_scale = 0.05
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
