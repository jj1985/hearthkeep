extends "res://scripts/entities/dragon_boss.gd"

# Ourzhal — the Storm Tyrant. Roosts above the Veiled Plane.
# Lightning sweeps + chain bolts + thunder-step relocation.

const T := preload("res://scripts/ui/ui_tokens.gd")

@onready var body: MeshInstance3D = $Body
var mat: StandardMaterial3D
var ability_t: float = 0.0

func _ready() -> void:
    super._ready()
    dragon_id = "ourzhal"
    max_hp = 1350.0
    hp = max_hp
    contact_damage = 22.0
    register_ability("chain_bolt", 4.0)
    register_ability("thunder_step", 6.0)
    register_ability("storm_field", 8.5)
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
        if is_ability_ready("chain_bolt") and global_position.distance_to(p.global_position) < 18.0:
            consume_ability("chain_bolt"); _do_chain_bolt(p)
    elif phase == Phase.AIR:
        if is_ability_ready("thunder_step"):
            consume_ability("thunder_step"); _do_thunder_step(p)
    elif phase == Phase.ENRAGED:
        if is_ability_ready("storm_field"):
            consume_ability("storm_field"); _do_storm_field(p)
        if is_ability_ready("chain_bolt"):
            consume_ability("chain_bolt"); _do_chain_bolt(p)

func _on_phase_entered(p: int) -> void:
    _apply_phase_visual()
    var msg: String = ""
    match p:
        Phase.AIR: msg = "Ourzhal climbs the wind!"
        Phase.ENRAGED: msg = "STORM HEART OPEN!"
    if msg != "":
        EventBus.floating_text.emit(msg, Vector2(global_position.x, global_position.z), T.TERTIARY)
        SfxBus.play("dragon_phase_air" if p == Phase.AIR else "dragon_phase_enraged", 0.0)
        EventBus.screen_shake.emit(0.6, 0.4)

func _apply_phase_visual() -> void:
    if mat == null: return
    match phase:
        Phase.GROUND:
            mat.albedo_color = Color("#1A2B40")
            mat.emission = Color("#3A6A9A")
            mat.emission_energy_multiplier = 0.6
        Phase.AIR:
            mat.albedo_color = Color("#243A55")
            mat.emission = Color("#5AA0E0")
            mat.emission_energy_multiplier = 1.6
        Phase.ENRAGED:
            mat.albedo_color = Color("#3A4D6E")
            mat.emission = Color("#9AC8FF")
            mat.emission_energy_multiplier = 4.0

func _do_chain_bolt(p: Node) -> void:
    EventBus.floating_text.emit("CHAIN BOLT", p.global_position, T.TERTIARY)
    if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 18.0:
        p.stats.take_damage(contact_damage * 0.7)

func _do_thunder_step(p: Node) -> void:
    var dest: Vector3 = p.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
    dest.y = global_position.y
    EventBus.floating_text.emit("THUNDERSTEP", global_position, T.WARNING)
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.18)
    tw.tween_callback(func(): global_position = dest)
    tw.tween_property(self, "modulate:a", 1.0, 0.18)
    tw.tween_callback(func():
        if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 5.0:
            p.stats.take_damage(contact_damage)
            EventBus.screen_shake.emit(0.7, 0.25))

func _do_storm_field(p: Node) -> void:
    EventBus.floating_text.emit("STORM FIELD", global_position, T.ERROR)
    EventBus.screen_shake.emit(0.5, 0.4)
    if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 10.0:
        p.stats.take_damage(contact_damage * 1.0)

func _on_died() -> void:
    EventBus.floating_text.emit("OURZHAL  STILLED", global_position, T.PRIMARY)
    SfxBus.play("dragon_roar", 2.0)
    EventBus.screen_shake.emit(1.2, 0.8)
    EventBus.hit_stop.emit(0.5)
    EventBus.boss_defeated.emit("ourzhal")
    GameState.add_gold(650)
    if Engine.has_singleton("VendorSystem"):
        VendorSystem.add_currency("dragon_shards", 12)
    for i in range(8):
        var ang: float = float(i) * TAU / 8.0
        var pos: Vector2 = Vector2(global_position.x + cos(ang) * 4.0, global_position.z + sin(ang) * 4.0)
        EventBus.loot_dropped.emit(LootSystem.roll_item(4), pos)
    var tw := create_tween()
    tw.tween_interval(2.5)
    tw.tween_callback(func():
        SaveSystem.save()
        get_tree().change_scene_to_file("res://scenes/villa/villa.tscn"))
