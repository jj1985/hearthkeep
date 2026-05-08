extends Area3D

@export var item: Dictionary = {}
var lifetime: float = 60.0
var bob_t: float = 0.0
var rarity: int = 0
var rarity_color: Color = Color.WHITE
var pillar: Node3D = null

@onready var sprite: MeshInstance3D = $Mesh
@onready var pickup_collider: CollisionShape3D = $Shape

func _ready() -> void:
    rarity = int(item.get("rarity", 0))
    rarity_color = LootSystem.RARITY_COLORS[rarity]
    if sprite != null and sprite.material_override != null:
        var m := sprite.material_override as StandardMaterial3D
        m.albedo_color = rarity_color
        m.emission_enabled = true
        m.emission = rarity_color
        m.emission_energy_multiplier = 1.0 + 0.6 * float(rarity)
    body_entered.connect(_on_body_entered)
    add_to_group("loot")
    pillar = VFX.spawn_loot_pillar_3d(global_position, rarity_color, 3.0 + 0.6 * float(rarity))
    if rarity >= LootSystem.Rarity.LEGENDARY:
        VFX.spawn_levelup_flare_3d(global_position)
        VFX.hit_stop(0.06)
    SfxBus.play("pickup", -3.0)

func _process(delta: float) -> void:
    bob_t += delta
    if sprite != null:
        sprite.position.y = 0.6 + sin(bob_t * 4.0) * 0.15
        sprite.rotation.y = bob_t * 1.5
    lifetime -= delta
    if lifetime <= 0.0:
        if pillar != null and is_instance_valid(pillar):
            pillar.queue_free()
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        EventBus.item_picked_up.emit(item)
        EventBus.floating_text.emit(item.get("name", "Item"), Vector2(global_position.x, global_position.z), rarity_color)
        SfxBus.play("pickup")
        if pillar != null and is_instance_valid(pillar):
            pillar.queue_free()
        queue_free()
