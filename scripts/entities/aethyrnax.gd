extends "res://scripts/entities/dragon_boss.gd"

# Aethyrnax — the Frost Sovereign of the high cold.
# Frost nova + ice shards + glacial breath. Slows on hit.

const T := preload("res://scripts/ui/ui_tokens.gd")

@onready var body: MeshInstance3D = $Body
var mat: StandardMaterial3D
var ability_t: float = 0.0

func _ready() -> void:
    super._ready()
    dragon_id = "aethyrnax"
    max_hp = 1500.0
    hp = max_hp
    contact_damage = 26.0
    register_ability("frost_nova", 6.0)
    register_ability("ice_shards", 3.5)
    register_ability("glacial_breath", 9.0)
    if body != null and body.get_active_material(0) != null:
        mat = body.get_active_material(0).duplicate()
        body.set_surface_override_material(0, mat)
        _apply_phase_visual()
    phase_entered.connect(_on_phase_entered)
    died.connect(_on_died)

func _process(delta: float) -> void:
    tick(delta)
    ability_t += delta
    var arr := get_tree().get_nodes_in_group("player")
    if arr.is_empty(): return
    var p = arr[0]
    look_at(Vector3(p.global_position.x, global_position.y, p.global_position.z), Vector3.UP)
    if phase == Phase.GROUND:
        if is_ability_ready("ice_shards") and global_position.distance_to(p.global_position) < 16.0:
            consume_ability("ice_shards"); _do_ice_shards(p)
    elif phase == Phase.AIR:
        if is_ability_ready("frost_nova"):
            consume_ability("frost_nova"); _do_frost_nova(p)
    elif phase == Phase.ENRAGED:
        if is_ability_ready("glacial_breath"):
            consume_ability("glacial_breath"); _do_glacial_breath(p)
        if is_ability_ready("ice_shards"):
            consume_ability("ice_shards"); _do_ice_shards(p)

func _on_phase_entered(p: int) -> void:
    _apply_phase_visual()
    var msg: String = ""
    match p:
        Phase.AIR: msg = "Aethyrnax climbs the cold!"
        Phase.ENRAGED: msg = "BLIZZARD HEART!"
    if msg != "":
        EventBus.floating_text.emit(msg, Vector2(global_position.x, global_position.z), T.TERTIARY)
        SfxBus.play("dragon_phase_air" if p == Phase.AIR else "dragon_phase_enraged", 0.0)
        EventBus.screen_shake.emit(0.6, 0.4)

func _apply_phase_visual() -> void:
    if mat == null: return
    match phase:
        Phase.GROUND:
            mat.albedo_color = Color("#2A3D5C")
            mat.emission = Color("#7AB8D6")
            mat.emission_energy_multiplier = 0.5
        Phase.AIR:
            mat.albedo_color = Color("#3D5878")
            mat.emission = Color("#9CD2EA")
            mat.emission_energy_multiplier = 1.5
        Phase.ENRAGED:
            mat.albedo_color = Color("#5276A0")
            mat.emission = Color("#D6F0FF")
            mat.emission_energy_multiplier = 3.5

func _do_ice_shards(p: Node) -> void:
    EventBus.floating_text.emit("ICE SHARDS", p.global_position, T.TERTIARY)
    if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 16.0:
        p.stats.take_damage(contact_damage * 0.6)

func _do_frost_nova(p: Node) -> void:
    EventBus.floating_text.emit("FROST NOVA", global_position, T.TERTIARY)
    EventBus.screen_shake.emit(0.5, 0.3)
    if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 10.0:
        p.stats.take_damage(contact_damage * 0.8)
        # Slow proxy: scaled RunState move-speed-mult drop for 2.5s
        var prev: float = RunState.move_speed_mult
        RunState.move_speed_mult = prev * 0.65
        var t := get_tree().create_timer(2.5)
        t.timeout.connect(func(): RunState.move_speed_mult = prev)

func _do_glacial_breath(p: Node) -> void:
    EventBus.floating_text.emit("GLACIAL BREATH", global_position, T.ERROR)
    EventBus.screen_shake.emit(0.7, 0.4)
    if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 14.0:
        p.stats.take_damage(contact_damage * 1.2)

func _on_died() -> void:
    EventBus.floating_text.emit("AETHYRNAX  SHATTERED", global_position, T.PRIMARY)
    SfxBus.play("dragon_roar", 2.0)
    EventBus.screen_shake.emit(1.2, 0.8)
    EventBus.hit_stop.emit(0.5)
    EventBus.boss_defeated.emit("aethyrnax")
    GameState.add_gold(800)
    if Engine.has_singleton("VendorSystem"):
        VendorSystem.add_currency("dragon_shards", 15)
    for i in range(10):
        var ang: float = float(i) * TAU / 10.0
        var pos: Vector2 = Vector2(global_position.x + cos(ang) * 4.0, global_position.z + sin(ang) * 4.0)
        EventBus.loot_dropped.emit(LootSystem.roll_item(4), pos)
    var tw := create_tween()
    tw.tween_interval(2.5)
    tw.tween_callback(func():
        SaveSystem.save()
        get_tree().change_scene_to_file("res://scenes/villa/villa.tscn"))
