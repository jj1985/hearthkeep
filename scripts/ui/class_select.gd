extends Control

# Character creator: pick a primary class, then optionally a secondary.
# Persists selection into RunState before scene-changing into the run.

const CLASS_ORDER := ["warrior", "rogue", "wizard", "necromancer", "bard", "paladin", "ranger"]

@onready var primary_row: HFlowContainer = $Scroll/Panel/Margin/V/PrimaryRow
@onready var secondary_row: HFlowContainer = $Scroll/Panel/Margin/V/SecondaryRow
@onready var blurb: Label = $Scroll/Panel/Margin/V/Blurb
@onready var hybrid_label: Label = $Scroll/Panel/Margin/V/HybridLabel
@onready var begin_btn: Button = $Scroll/Panel/Margin/V/BottomRow/BeginButton
@onready var back_btn: Button = $Scroll/Panel/Margin/V/BottomRow/BackButton

var primary_buttons: Array[Button] = []
var secondary_buttons: Array[Button] = []
var pending_primary: String = "warrior"
var pending_secondary: String = ""

func _ready() -> void:
    for id in CLASS_ORDER:
        primary_buttons.append(_make_class_button(primary_row, id, _on_primary_picked))
        secondary_buttons.append(_make_class_button(secondary_row, id, _on_secondary_picked))
    begin_btn.pressed.connect(_on_begin)
    back_btn.pressed.connect(_on_back)
    _refresh()

func _make_class_button(parent: HFlowContainer, id: String, cb: Callable) -> Button:
    var b := Button.new()
    var def: Dictionary = Classes.get_class_def(id)
    b.text = def.get("name", id.capitalize())
    b.set_meta("class_id", id)
    b.custom_minimum_size = Vector2(140, 56)
    b.pressed.connect(cb.bind(id))
    parent.add_child(b)
    return b

func _on_primary_picked(id: String) -> void:
    pending_primary = id
    if pending_secondary == id:
        pending_secondary = ""
    _refresh()

func _on_secondary_picked(id: String) -> void:
    if id == pending_primary or id == pending_secondary:
        pending_secondary = ""    # toggle off when re-clicking the chosen one
    else:
        pending_secondary = id
    _refresh()

func _refresh() -> void:
    for b in primary_buttons:
        var sel: bool = (b.get_meta("class_id") == pending_primary)
        b.modulate = Color(1.0, 0.85, 0.35) if sel else Color(0.85, 0.85, 0.85)
    for b in secondary_buttons:
        var id: String = b.get_meta("class_id")
        var sel: bool = (id == pending_secondary)
        var locked: bool = (id == pending_primary)
        b.disabled = locked
        b.modulate = Color(0.85, 0.6, 1.0) if sel else (Color(0.4, 0.4, 0.4) if locked else Color(0.85, 0.85, 0.85))
    var pdef: Dictionary = Classes.get_class_def(pending_primary)
    var blurb_txt: String = pdef.get("blurb", "")
    if pending_secondary != "":
        var sdef: Dictionary = Classes.get_class_def(pending_secondary)
        blurb_txt = "%s\n\n+ %s — %s" % [blurb_txt, sdef.get("name", ""), sdef.get("blurb", "")]
    blurb.text = blurb_txt
    var hybrid: Dictionary = Classes.hybrid_for(pending_primary, pending_secondary) if pending_secondary != "" else {}
    if hybrid.is_empty():
        hybrid_label.text = "Single-class run" if pending_secondary == "" else "Multiclass — no named prestige"
        hybrid_label.modulate = Color(0.7, 0.7, 0.7)
    else:
        hybrid_label.text = "★ %s — %s" % [hybrid.get("name", ""), hybrid.get("perk", "")]
        hybrid_label.modulate = Color(1.0, 0.8, 0.4)

func _on_begin() -> void:
    if not RunState.set_classes(pending_primary, pending_secondary):
        return
    get_tree().change_scene_to_file("res://scenes/run.tscn")

func _on_back() -> void:
    get_tree().change_scene_to_file("res://scenes/title.tscn")
