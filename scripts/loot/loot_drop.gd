extends Area2D

@export var item: Dictionary = {}
var pickup_distance: float = 32.0
var lifetime: float = 60.0
var bob_t: float = 0.0
var rarity: int = 0
var rarity_color: Color = Color.WHITE

@onready var sprite: Polygon2D = $Sprite
@onready var aura: Polygon2D = $Aura
@onready var label: Label = $Label

func _ready() -> void:
    rarity = int(item.get("rarity", 0))
    rarity_color = LootSystem.RARITY_COLORS[rarity]
    sprite.color = rarity_color
    aura.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
    label.text = item.get("name","Item")
    label.modulate = rarity_color
    body_entered.connect(_on_body_entered)
    add_to_group("loot")
    VFX.spawn_loot_pillar(global_position, rarity_color, 64.0 + 18.0 * float(rarity))

func _process(delta: float) -> void:
    bob_t += delta
    sprite.position.y = sin(bob_t * 4.0) * 3.0
    aura.rotation += delta * 1.5
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        if body.has_method("equipped"):
            pass
        if body.has_meta("inventory_ref") or true:
            EventBus.item_picked_up.emit(item)
            SfxBus.play("pickup")
            EventBus.floating_text.emit(item.get("name", "Item"), global_position + Vector2(0, -32), rarity_color)
            queue_free()
