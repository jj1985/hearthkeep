extends CharacterBody3D

const CharacterStats := preload("res://scripts/entities/character_stats.gd")

@export var class_primary: String = "warrior"
@export var class_secondary: String = ""

var stats: CharacterStats
var attack_cooldown: float = 0.0
var dodge_cooldown: float = 0.0
var dodge_timer: float = 0.0
var dodging: bool = false
var facing: Vector3 = Vector3.FORWARD
var equipped: Dictionary = {}                 # mirrors Inventory.equipped
var aim_dir: Vector3 = Vector3.FORWARD
var move_dir: Vector3 = Vector3.ZERO
var revive_used: bool = false

@onready var body_mesh: MeshInstance3D = $Body
@onready var helm_mesh: MeshInstance3D = $Body/Helm
@onready var cloak_mesh: MeshInstance3D = $Body/Cloak
@onready var weapon_mesh: MeshInstance3D = $WeaponMount/Weapon
@onready var weapon_mount: Node3D = $WeaponMount
@onready var attack_area: Area3D = $AttackArea
@onready var attack_shape: CollisionShape3D = $AttackArea/Shape
@onready var aura_root: Node3D = $AuraRoot

signal player_attacked(direction)

func _ready() -> void:
    stats = CharacterStats.new()
    _apply_class_base()
    _refresh_dye_overlay()
    EventBus.perk_chosen.connect(_on_perk_chosen)
    EventBus.weapon_evolved.connect(_on_weapon_evolved)
    Inventory.equipment_changed.connect(_on_equipment_changed)
    add_to_group("player")

func _apply_class_base() -> void:
    if Classes.get_class_def(class_primary).is_empty():
        return
    var res: Dictionary = Classes.combined_resources(class_primary, class_secondary)
    stats.max_hp = float(res["hp"]) * RunState.max_hp_mult
    stats.hp = stats.max_hp
    stats.max_mp = float(res["mp"])
    stats.mp = stats.max_mp
    stats.armor = float(res["armor"])
    stats.move_speed = 6.0
    var profile: Dictionary = Classes.combined_stat_profile(class_primary, class_secondary)
    stats.damage = 6.0 + float(profile.get("str", 5)) * 0.5 + float(profile.get("int", 5)) * 0.4
    stats.crit_chance = 0.05 + float(profile.get("agi", 5)) * 0.005
    _apply_allocated_talents()
    _apply_trophy_buffs()

func _apply_trophy_buffs() -> void:
    # Pull aggregate from TrophyManager (handles active-buff cap + set
    # bonuses internally) and route into player stats / RunState.
    if not Engine.has_singleton("TrophyManager"):
        return
    var agg: Dictionary = TrophyManager.aggregate_buffs()
    for k in agg.keys():
        var v: float = float(agg[k])
        match String(k):
            "max_hp":         stats.max_hp += v
            "max_mp":         stats.max_mp += v
            "armor":          stats.armor += v
            "damage":         stats.damage += v
            "crit_chance":    stats.crit_chance += v
            "crit_damage":    RunState.crit_damage_bonus += v
            "atk_speed":      RunState.atk_speed_mult *= (1.0 + v)
            "move_speed":     RunState.move_speed_mult *= (1.0 + v)
            "lifesteal":      RunState.lifesteal_pct += v
            "thorns":         RunState.thorns_pct += v
            "fire_dmg":       RunState.fire_dot_chance += v * 0.01
            "frost_dmg":      RunState.frost_slow_chance += v * 0.01
            "lightning_dmg":  RunState.lightning_chain_chance += v * 0.01
            "magic_find":     RunState.pickup_radius_mult *= (1.0 + v * 0.01)
            "aoe":            RunState.aoe_mult *= (1.0 + v)
            _: pass

func _apply_allocated_talents() -> void:
    # Walk RunState.allocated_talents and apply stat bumps from the
    # talent definitions in TalentDB. Stat keys mapped to player stats
    # below; unknown keys are ignored (so designers can add new talent
    # effects without breaking the runtime).
    var def: Dictionary = Classes.get_class_def(class_primary)
    var tree_id: String = String(def.get("talent_tree", ""))
    for node_id in RunState.allocated_talents.keys():
        if not bool(RunState.allocated_talents[node_id]):
            continue
        var n: Dictionary = TalentDB.get_talent_node(tree_id, String(node_id))
        if n.is_empty():
            continue
        var effect: Dictionary = n.get("stat", {})
        for k in effect.keys():
            var v: float = float(effect[k])
            match String(k):
                "str":            stats.damage += v * 0.5
                "agi":            stats.crit_chance += v * 0.005
                "int":            stats.damage += v * 0.4
                "sta":            stats.max_hp += v * 5.0
                "max_hp":         stats.max_hp += v
                "max_mp":         stats.max_mp += v
                "armor":          stats.armor += v
                "crit_chance":    stats.crit_chance += v
                "crit_dmg":       RunState.crit_damage_bonus += v
                "atk_speed":      RunState.atk_speed_mult *= (1.0 + v)
                "move_speed":     RunState.move_speed_mult *= (1.0 + v)
                "lifesteal":      RunState.lifesteal_pct += v
                "healing":        stats.max_hp += v * 5.0
                "fire_dmg":       RunState.fire_dot_chance += v * 0.01
                "frost_dmg":      RunState.frost_slow_chance += v * 0.01
                "lightning_dmg":  RunState.lightning_chain_chance += v * 0.01
                "aoe":            RunState.aoe_mult *= (1.0 + v)
                _: pass    # unmapped stat — designer can add the mapping later
    stats.hp = stats.max_hp
    stats.mp = stats.max_mp

func equipped_weapon_tags() -> Array:
    var tags: Array = []
    var mh: Variant = Inventory.equipped.get("main_hand", null)
    if typeof(mh) == TYPE_DICTIONARY:
        for t in (mh as Dictionary).get("tags", []):
            tags.append(t)
    return tags

func current_damage() -> float:
    var d := stats.damage * RunState.damage_mult
    var weapon_dmg := 0.0
    var mh: Variant = Inventory.equipped.get("main_hand", null)
    if typeof(mh) == TYPE_DICTIONARY:
        var s: Dictionary = (mh as Dictionary).get("stats", {})
        weapon_dmg = (float(s.get("dmg_min", 0)) + float(s.get("dmg_max", 0))) * 0.5
    return d + weapon_dmg

func current_attack_speed() -> float:
    var atk: float = stats.attack_speed * RunState.atk_speed_mult * (1.0 + BuffSystem.aggregate_mod("atk_speed_mult"))
    # Berserker hybrid: below 50% HP, +30% atk speed
    if _has_hybrid("berserker") and stats.hp < stats.max_hp * 0.5:
        atk *= 1.30
    return atk

func current_crit_chance() -> float:
    var c: float = stats.crit_chance + RunState.crit_chance_bonus
    # Berserker hybrid: below 50% HP, +40% crit chance
    if _has_hybrid("berserker") and stats.hp < stats.max_hp * 0.5:
        c += 0.40
    return clampf(c, 0.0, 1.0)

func _has_hybrid(id: String) -> bool:
    if class_secondary == "":
        return false
    var h: Dictionary = Classes.hybrid_for(class_primary, class_secondary)
    return String(h.get("id", "")) == id

func _has_talent(node_id: String) -> bool:
    return bool(RunState.allocated_talents.get(node_id, false))

func current_move_speed() -> float:
    return stats.move_speed * RunState.move_speed_mult

func _physics_process(delta: float) -> void:
    if stats.is_dead():
        return
    attack_cooldown = max(0.0, attack_cooldown - delta)
    dodge_cooldown = max(0.0, dodge_cooldown - delta)
    dodge_timer = max(0.0, dodge_timer - delta)
    _process_skill_cooldowns(delta)
    dodging = dodge_timer > 0.0

    var input := Vector3(
        Input.get_axis("move_left","move_right"), 0,
        Input.get_axis("move_up","move_down"))
    if input.length() > 1.0:
        input = input.normalized()
    move_dir = input
    if input.length() > 0.1:
        facing = input.normalized()
        aim_dir = facing

    var speed_mult: float = 1.7 if dodging else 1.0
    velocity = input * current_move_speed() * speed_mult
    move_and_slide()

    if facing.length() > 0.01:
        var ang: float = atan2(facing.x, facing.z)
        rotation.y = lerp_angle(rotation.y, ang, 0.25)
        weapon_mount.rotation.y = 0.0

    if Input.is_action_just_pressed("attack"):
        _attack()
    if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0:
        dodge_cooldown = 0.6
        dodge_timer = 0.18
        VFX.spawn_hit_burst_3d(global_position, Color(0.6, 0.8, 1.0), 0.6)
    if Input.is_action_just_pressed("potion_hp"):
        _use_potion("hp")
    if Input.is_action_just_pressed("potion_mp"):
        _use_potion("mp")
    if Input.is_action_just_pressed("skill_1"):
        _cast_skill(0)
    if Input.is_action_just_pressed("skill_2"):
        _cast_skill(1)
    if Input.is_action_just_pressed("skill_3"):
        _cast_skill(2)
    if Input.is_action_just_pressed("skill_4"):
        _cast_skill(3)

func _attack() -> void:
    if attack_cooldown > 0.0:
        return
    attack_cooldown = 0.55 / max(0.1, current_attack_speed())
    player_attacked.emit(facing)
    attack_area.position = facing * 1.4
    attack_area.monitoring = true
    var hits: Array[Node3D] = attack_area.get_overlapping_bodies()
    var damage_dealt := false
    for body in hits:
        if body.is_in_group("enemy") and body.has_method("take_damage"):
            var roll_crit: bool = randf() < current_crit_chance()
            var dmg: float = current_damage() * (stats.crit_damage + RunState.crit_damage_bonus if roll_crit else 1.0)
            # Execute: Ender (warrior keystone) — below 35% HP, one-shot non-elites
            if _has_talent("w_key2") and (body as Object).get("stats") != null:
                var es: Object = (body as Object).stats
                var hp_pct: float = float(es.hp) / max(1.0, float(es.max_hp))
                var is_elite: bool = String((body as Object).get("monster_id_value")) == "warchief"
                if hp_pct < 0.35 and not is_elite:
                    dmg = float(es.max_hp) + 1.0
                    EventBus.floating_text.emit("EXECUTE", (body as Node3D).global_position, Color(1, 0.4, 0.3))
            (body as Object).call("take_damage", dmg, self, roll_crit)
            damage_dealt = true
    if damage_dealt:
        VFX.hit_stop(0.04)
        VFX.spawn_hit_burst_3d(global_position + facing * 1.4 + Vector3.UP * 0.7, Color(1, 1, 1))
        SfxBus.play("hit")
    if RunState.weapon_evolutions.has("sunfire_reaver"):
        for body in get_tree().get_nodes_in_group("enemy"):
            if not is_instance_valid(body): continue
            var n3d: Node3D = body as Node3D
            if n3d == null: continue
            if global_position.distance_to(n3d.global_position) < 3.5:
                if body.has_method("take_damage"):
                    (body as Object).call("take_damage", current_damage() * 0.25, self, false)

func take_damage(amount: float, _src: Object) -> void:
    if dodging:
        return
    var reduction: float = BuffSystem.aggregate_mod("damage_reduction")
    var mitigated: float = stats.mitigate(amount) * (1.0 - reduction)
    stats.hp = max(0.0, stats.hp - mitigated)
    EventBus.damage_dealt.emit(_src, self, mitigated, false)
    EventBus.floating_text.emit(str(int(mitigated)), Vector2(global_position.x, global_position.z), Color(1, 0.4, 0.4))
    VFX.spawn_hit_burst_3d(global_position + Vector3.UP, Color(1, 0.3, 0.3), 0.7)
    VFX.screen_shake(3.0, 0.1)
    if stats.is_dead():
        if not revive_used and TrophyManager.active_buff_ids.has("phoenix_plume"):
            revive_used = true
            stats.hp = stats.max_hp * 0.30
            VFX.spawn_levelup_flare_3d(global_position)
            EventBus.floating_text.emit("PHOENIX REVIVE", Vector2(global_position.x, global_position.z), Color(1, 0.6, 0.4))
            return
        EventBus.player_died.emit()
    if RunState.thorns_pct > 0.0 and _src is Node3D and (_src as Node).is_in_group("enemy"):
        if (_src as Object).has_method("take_damage"):
            (_src as Object).call("take_damage", mitigated * RunState.thorns_pct, self, false)

# Per-class skill kits. Slots 0..3 map to skill_1..skill_4 (Q/E/R/F).
# Each entry: { name, cooldown, mana_cost, callable }.  Class kits chosen
# from the first 4 skills in Classes.CLASSES[primary]["skills"]; secondary
# class slot 0 + 1 are appended in slots 4..5 (currently unbound — Q/E/R/F
# only exposes 4 buttons; future "swap" panel can switch active row).

var skill_cds: Dictionary = {}    # slot_index -> remaining cooldown

func _cast_skill(slot: int) -> void:
    var def: Dictionary = Classes.get_class_def(class_primary)
    var skills: Array = def.get("skills", [])
    if slot >= skills.size():
        return
    var skill_id: String = String(skills[slot])
    var cd: float = float(skill_cds.get(slot, 0.0))
    if cd > 0.0:
        EventBus.floating_text.emit("%s on cooldown (%.1fs)" % [skill_id, cd], Vector2.ZERO, T_color_warning())
        return
    var mana_cost: float = _skill_mana_cost(skill_id)
    if stats.mp < mana_cost:
        EventBus.floating_text.emit("Out of mana", Vector2.ZERO, T_color_error())
        return
    stats.mp -= mana_cost
    var dur: float = _skill_cooldown(skill_id)
    skill_cds[slot] = dur
    _resolve_skill(skill_id)

func _skill_cooldown(id: String) -> float:
    match id:
        "fireball", "frost_nova", "chain_lightning": return 4.0
        "backstab", "shadow_step": return 5.0
        "cleave", "whirlwind": return 6.0
        "raise_skeleton", "corpse_explosion": return 8.0
        "smite", "consecrate", "blessing_of_might": return 5.0
        "volley", "aimed_shot", "trap": return 4.5
        "dissonance", "heroic_anthem": return 6.0
    return 5.0

func _skill_mana_cost(id: String) -> float:
    match id:
        "fireball", "frost_nova", "chain_lightning", "arcane_orb": return 18.0
        "raise_skeleton", "corpse_explosion", "bone_spear": return 16.0
        "cleave", "whirlwind", "backstab", "shadow_step", "smite", "volley": return 8.0
    return 12.0

func _resolve_skill(id: String) -> void:
    SfxBus.play("crit", -3.0)
    EventBus.floating_text.emit(id.replace("_", " ").to_upper(), global_position, Color(1, 0.85, 0.4))
    var aoe_radius: float = 5.0
    var dmg_mult: float = 2.2
    var element: String = "physical"
    match id:
        "fireball":
            aoe_radius = 4.0
            dmg_mult = 2.6
            element = "fire"
            VFX.spawn_hit_burst_3d(global_position + facing * 4.0 + Vector3.UP, Color(1, 0.5, 0.1), 1.6)
        "frost_nova":
            aoe_radius = 5.0
            dmg_mult = 1.8
            element = "frost"
            VFX.spawn_hit_burst_3d(global_position + Vector3.UP, Color(0.6, 0.85, 1.0), 1.4)
        "chain_lightning":
            aoe_radius = 8.0
            dmg_mult = 1.6
            element = "lightning"
            VFX.spawn_hit_burst_3d(global_position + Vector3.UP, Color(0.7, 0.9, 1.0), 1.2)
        "backstab":
            aoe_radius = 1.6
            dmg_mult = 3.5
            VFX.spawn_crit_burst_3d(global_position + facing * 1.6 + Vector3.UP, Color(0.85, 0.2, 0.85))
        "cleave":
            aoe_radius = 3.0
            dmg_mult = 1.6
            VFX.spawn_hit_burst_3d(global_position + facing * 1.6 + Vector3.UP, Color(1, 1, 1), 1.4)
        "whirlwind":
            aoe_radius = 4.0
            dmg_mult = 1.4
            VFX.spawn_hit_burst_3d(global_position + Vector3.UP, Color(0.95, 0.8, 0.4), 1.6)
        "smite":
            aoe_radius = 1.8
            dmg_mult = 2.4
            VFX.spawn_hit_burst_3d(global_position + facing * 2.0 + Vector3.UP * 1.5, Color(1, 0.95, 0.5), 1.4)
        "volley", "aimed_shot":
            aoe_radius = 2.5
            dmg_mult = 2.0
        "blessing_of_might", "heroic_anthem", "haste":
            BuffSystem.apply("haste" if id == "haste" else "blessing_might", BuffSystem.SOURCE_CLASS_SKILL)
            return
    # AOE damage application
    var origin: Vector3 = global_position + facing * 2.0
    for e in get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(e): continue
        var en: Node3D = e as Node3D
        if origin.distance_to(en.global_position) <= aoe_radius and (e as Object).has_method("take_damage"):
            var roll_crit: bool = randf() < current_crit_chance()
            var dmg: float = current_damage() * dmg_mult * (stats.crit_damage if roll_crit else 1.0)
            (e as Object).call("take_damage", dmg, self, roll_crit)

func T_color_warning() -> Color:
    return Color(0.78, 0.62, 0.18)
func T_color_error() -> Color:
    return Color(0.65, 0.20, 0.20)

func _process_skill_cooldowns(delta: float) -> void:
    for k in skill_cds.keys():
        skill_cds[k] = max(0.0, float(skill_cds[k]) - delta)

func _use_potion(kind: String) -> void:
    EventBus.potion_used.emit(kind)
    SfxBus.play("potion")
    if kind == "hp":
        var heal: float = stats.max_hp * 0.45
        if stats.hp < stats.max_hp * 0.25:
            heal *= 1.5    # low-HP bonus per loading-screen tip + design pillar
        var prev: float = stats.hp
        stats.hp = min(stats.max_hp, stats.hp + heal)
        VFX.spawn_hit_burst_3d(global_position + Vector3.UP * 0.5, Color(0.95, 0.2, 0.4), 1.2)
        EventBus.floating_text.emit("+%d HP" % int(round(stats.hp - prev)),
            Vector2(global_position.x, global_position.z), Color(0.55, 0.85, 0.55))
    elif kind == "mp":
        var prev_mp: float = stats.mp
        stats.mp = min(stats.max_mp, stats.mp + stats.max_mp * 0.5)
        VFX.spawn_hit_burst_3d(global_position + Vector3.UP * 0.5, Color(0.3, 0.5, 1.0), 1.2)
        EventBus.floating_text.emit("+%d MP" % int(round(stats.mp - prev_mp)),
            Vector2(global_position.x, global_position.z), Color(0.5, 0.7, 1.0))

func _refresh_dye_overlay() -> void:
    var head_color: Color = DyeSystem.dye_for("head")
    var chest_color: Color = DyeSystem.dye_for("chest")
    var cloak_color: Color = DyeSystem.dye_for("cloak")
    if helm_mesh != null and helm_mesh.material_override != null:
        (helm_mesh.material_override as StandardMaterial3D).albedo_color = head_color
    if body_mesh != null and body_mesh.material_override != null:
        (body_mesh.material_override as StandardMaterial3D).albedo_color = chest_color
    if cloak_mesh != null and cloak_mesh.material_override != null:
        (cloak_mesh.material_override as StandardMaterial3D).albedo_color = cloak_color

func gain_xp(amount: float) -> void:
    RunState.add_xp(amount * RunState.wager_multiplier)

func _on_perk_chosen(_id: String) -> void:
    var new_max: float = stats.max_hp
    if not Classes.get_class_def(class_primary).is_empty():
        var res: Dictionary = Classes.combined_resources(class_primary, class_secondary)
        new_max = float(res["hp"]) * RunState.max_hp_mult
    var hp_ratio: float = stats.hp / max(1.0, stats.max_hp)
    stats.max_hp = new_max
    stats.hp = clamp(new_max * hp_ratio, 0.0, new_max)

func _on_weapon_evolved(_from, evo_id: String) -> void:
    EventBus.floating_text.emit("EVOLVED!", Vector2(global_position.x, global_position.z), Color(1, 0.6, 1))
    VFX.spawn_levelup_flare_3d(global_position)
    if evo_id == "sunfire_reaver":
        VFX.spawn_fire_ring_3d(self, 2.5)

func _on_equipment_changed() -> void:
    _refresh_dye_overlay()
    var mh: Variant = Inventory.equipped.get("main_hand", null)
    if typeof(mh) == TYPE_DICTIONARY and weapon_mesh != null:
        var rarity: int = int((mh as Dictionary).get("rarity", 0))
        var color: Color = LootSystem.RARITY_COLORS[rarity]
        if weapon_mesh.material_override != null:
            (weapon_mesh.material_override as StandardMaterial3D).albedo_color = color.lerp(Color(0.85, 0.85, 0.95), 0.5)
            (weapon_mesh.material_override as StandardMaterial3D).emission = color
            (weapon_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6 + 0.4 * float(rarity)
