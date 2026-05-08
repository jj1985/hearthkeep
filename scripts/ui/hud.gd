extends Control

@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var mp_bar: ProgressBar = $TopLeft/MPBar
@onready var xp_bar: ProgressBar = $TopBar/XPBar
@onready var lvl_label: Label = $TopBar/LevelLabel
@onready var gold_label: Label = $TopRight/GoldLabel
@onready var floor_label: Label = $TopBar/FloorLabel
@onready var perk_strip: HBoxContainer = $BottomLeft/PerkStrip
@onready var virtual_stick: Control = $VirtualStick

var player: Node = null
var perk_chips: Array = []

func _ready() -> void:
    EventBus.perk_chosen.connect(_on_perk_chosen)
    EventBus.weapon_evolved.connect(_on_weapon_evolved)
    EventBus.currency_changed.connect(_on_currency_changed)
    if not OS.has_feature("mobile") and not OS.has_feature("web"):
        virtual_stick.visible = false

func _process(_delta: float) -> void:
    if player == null:
        var p_arr := get_tree().get_nodes_in_group("player")
        if p_arr.is_empty():
            return
        player = p_arr[0]
    if player.has_method("get") and (player as Node).get("stats") != null:
        var s = player.stats
        hp_bar.value = s.hp / max(1.0, s.max_hp) * 100.0
        mp_bar.value = s.mp / max(1.0, s.max_mp) * 100.0
    xp_bar.value = (RunState.xp / max(0.001, RunState.xp_to_next)) * 100.0
    lvl_label.text = "Lv " + str(RunState.player_level)
    floor_label.text = "Floor " + str(RunState.floor_index + 1)
    gold_label.text = "Gold: " + str(GameState.gold)

func _on_perk_chosen(id: String) -> void:
    var lbl := Label.new()
    lbl.text = id.replace("u_", "").replace("_", " ")
    lbl.modulate = Color(0.95, 0.85, 0.4)
    lbl.add_theme_font_size_override("font_size", 12)
    perk_strip.add_child(lbl)
    perk_chips.append(lbl)
    if perk_chips.size() > 12:
        var oldest = perk_chips.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()

func _on_weapon_evolved(_from, evo_id: String) -> void:
    var lbl := Label.new()
    lbl.text = "★ " + evo_id.to_upper().replace("_", " ")
    lbl.modulate = Color(1, 0.55, 1)
    lbl.add_theme_font_size_override("font_size", 14)
    perk_strip.add_child(lbl)

func _on_currency_changed(_kind, _delta, _total) -> void:
    pass
