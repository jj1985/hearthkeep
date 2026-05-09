extends Control

# Town visit screen. Reads Towns autoload + RumorPool, renders the
# town's named NPC roster as tappable cards. Tapping pulls a rumor
# from the pool + biases by NPC role.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var subhead: Label = $SafeArea/V/Subhead
@onready var npc_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var dialogue_panel: PanelContainer = $SafeArea/V/Dialogue
@onready var dialogue_speaker: Label = $SafeArea/V/Dialogue/Margin/V/Speaker
@onready var dialogue_text: Label = $SafeArea/V/Dialogue/Margin/V/Text
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var town_id: String = "coastreach"
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    subhead.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    subhead.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    dialogue_panel.add_theme_stylebox_override("panel", UiStyle_.panel_modal())
    dialogue_speaker.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    dialogue_speaker.add_theme_color_override("font_color", T.PRIMARY)
    dialogue_text.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    dialogue_text.add_theme_color_override("font_color", T.ON_SURFACE)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(close_btn)
    close_btn.pressed.connect(_on_close)
    dialogue_panel.visible = false
    _resolve_town()
    _populate_npcs()

func _resolve_town() -> void:
    # Read from a global "Towns.last_visited" if set (Phase B), else
    # default to the player's bond location's matching town if any.
    var bond: String = TravelSystem.bond_location
    var bond_to_town := {
        "valehome_keep": "coastreach",
        "duskport_alley": "coastreach",
        "thalanore_canopy": "canopyhall",
        "graymarrow_gate": "black_bastion",
        "ashfen_outpost": "black_bastion",
        "fearhollow_seal": "black_bastion",
        "ruinmarch_camp": "black_bastion",
    }
    town_id = String(bond_to_town.get(bond, "coastreach"))
    var t = Towns.get_town(town_id)
    if t != null:
        var s: Dictionary = t.summary()
        headline.text = String(s["name"]).to_upper()
        subhead.text = "%s  ·  ruled by %s, %s  ·  mood: %s" % [
            String(s["region"]), String(s["ruler_name"]),
            String(s["ruler_title"]), String(s["mood_label"])]

func _populate_npcs() -> void:
    for c in npc_list.get_children():
        c.queue_free()
    var t = Towns.get_town(town_id)
    if t == null:
        return
    for n in t.npcs:
        npc_list.add_child(_npc_card(n))

func _npc_card(npc: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var head := HBoxContainer.new()
    v.add_child(head)
    var name_label := Label.new()
    name_label.text = String(npc.get("name", "?"))
    name_label.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    name_label.add_theme_color_override("font_color", T.PRIMARY)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(name_label)
    var role_label := Label.new()
    role_label.text = String(npc.get("role", "")).to_upper()
    role_label.add_theme_font_size_override("font_size", T.FS_LABEL_MD)
    role_label.add_theme_color_override("font_color", T.SECONDARY)
    head.add_child(role_label)
    var blurb := Label.new()
    blurb.text = String(npc.get("blurb", ""))
    blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    blurb.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    blurb.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    v.add_child(blurb)
    var btn := Button.new()
    btn.text = "TALK"
    btn.custom_minimum_size = Vector2(120, 40)
    UiStyle_.apply_primary(btn)
    UiAnim_.bind_press_feedback(btn)
    btn.pressed.connect(_on_talk.bind(npc))
    v.add_child(btn)
    return panel

func _on_talk(npc: Dictionary) -> void:
    dialogue_speaker.text = "%s, %s" % [String(npc.get("name", "?")), String(npc.get("role", ""))]
    var line: String = ""
    if Engine.has_singleton("RumorPool"):
        var rumor: Variant = RumorPool.draw() if RumorPool.has_method("draw") else null
        if rumor is String:
            line = String(rumor)
        elif rumor is Dictionary:
            line = String((rumor as Dictionary).get("text", ""))
    if line == "":
        # Fallback: generic role-flavored line
        line = _fallback_line(String(npc.get("role", "")))
    dialogue_text.text = "\"%s\"" % line
    dialogue_panel.visible = true
    SfxBus.play("perk_pick", -8.0)

func _fallback_line(role: String) -> String:
    match role:
        "tavernkeeper":  return "Coin first, story after. That's the rule."
        "blacksmith":    return "Sword's only as good as the arm holding it. Sit. Eat first."
        "harbormaster":  return "I count ships. Most of them come back."
        "bard":          return "Have you heard the new ballad? Of course you haven't."
        "lighthouse keeper": return "I haven't slept since the Sundering. I'll sleep when it lets me."
        "war-priestess of Thaen": return "Thaen has eight words. None of them are 'maybe'."
        "scout":         return "Smoke east of the river last night. Third time this month."
        "ranger-master": return "Drake roost spotted at the upper boughs. Bring the right oils."
        "alchemist":     return "Three of my brews are illegal in the Coastreach. Want one?"
        "stable-master": return "Horses know things. Listen to them when they don't move."
    return "The road is long, and the realms remember."

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
