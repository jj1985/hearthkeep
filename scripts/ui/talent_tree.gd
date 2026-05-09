extends Control

# Talent tree allocator. Reads the player's primary class talent tree
# from TalentDB and renders nodes as a vertical list (Phase A — full
# graph layout with prereq edges is Phase B). Player spends RunState
# talent_points on nodes whose prereqs are met.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var subhead: Label = $SafeArea/V/Subhead
@onready var node_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var class_id: String = ""
var tree_id: String = ""
var prereqs: Dictionary = {}   # node_id -> array of prereq node ids

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    subhead.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    subhead.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(close_btn)
    close_btn.pressed.connect(_on_close)
    class_id = RunState.class_primary
    var def: Dictionary = Classes.get_class_def(class_id)
    tree_id = String(def.get("talent_tree", ""))
    headline.text = "%s  TALENTS" % String(def.get("name", "?")).to_upper()
    _populate_prereqs()
    _refresh()

func _populate_prereqs() -> void:
    var def: Dictionary = TalentDB.get_tree_def(tree_id)
    prereqs.clear()
    for edge in def.get("edges", []):
        var from_id: String = String(edge[0])
        var to_id: String = String(edge[1])
        if not prereqs.has(to_id):
            prereqs[to_id] = []
        prereqs[to_id].append(from_id)

func _refresh() -> void:
    for c in node_list.get_children():
        c.queue_free()
    var def: Dictionary = TalentDB.get_tree_def(tree_id)
    subhead.text = "Spend  %d  talent points" % RunState.talent_points
    for n in def.get("nodes", []):
        node_list.add_child(_make_node_card(n))

func _make_node_card(node: Dictionary) -> Control:
    var nid: String = String(node["id"])
    var allocated: bool = bool(RunState.allocated_talents.get(nid, false))
    var prereqs_met: bool = _prereqs_met(nid)
    var keystone: bool = bool(node.get("k", false))
    var panel := PanelContainer.new()
    var sb: StyleBoxFlat = UiStyle_.card_resting()
    if keystone:
        sb = UiStyle_.card_evolution()
    elif allocated:
        sb.border_color = T.PRIMARY
        sb.set_border_width_all(2)
    elif not prereqs_met:
        sb.bg_color = Color(T.SURFACE.r, T.SURFACE.g, T.SURFACE.b, 0.4)
    panel.add_theme_stylebox_override("panel", sb)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var head := HBoxContainer.new()
    v.add_child(head)
    var name_label := Label.new()
    name_label.text = String(node.get("name", nid))
    name_label.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    name_label.add_theme_color_override("font_color",
        T.PRIMARY if (allocated or keystone) else (T.ON_SURFACE if prereqs_met else T.ON_SURFACE_DISABLED))
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(name_label)
    var btn := Button.new()
    if allocated:
        btn.text = "TAKEN"
        btn.disabled = true
    elif not prereqs_met:
        btn.text = "LOCKED"
        btn.disabled = true
    elif RunState.talent_points <= 0:
        btn.text = "+1"
        btn.disabled = true
    else:
        btn.text = "+1"
        btn.pressed.connect(_allocate.bind(nid))
    btn.custom_minimum_size = Vector2(96, 40)
    UiStyle_.apply_primary(btn) if (not btn.disabled) else UiStyle_.apply_secondary(btn)
    UiAnim_.bind_press_feedback(btn)
    head.add_child(btn)
    var blurb := Label.new()
    if node.has("effect"):
        blurb.text = String(node["effect"])
    else:
        var stats: Dictionary = node.get("stat", {})
        var parts: Array = []
        for k in stats.keys():
            parts.append("%s +%s" % [String(k), str(stats[k])])
        blurb.text = ", ".join(parts) if not parts.is_empty() else ""
    blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    blurb.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    blurb.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    v.add_child(blurb)
    if not _prereqs_met(nid) and prereqs.has(nid):
        var req := Label.new()
        var names: Array = []
        for pid in prereqs[nid]:
            var pn: Dictionary = TalentDB.get_talent_node(tree_id, pid)
            names.append(String(pn.get("name", pid)))
        req.text = "Requires:  %s" % ", ".join(names)
        req.add_theme_font_size_override("font_size", T.FS_LABEL_SM)
        req.add_theme_color_override("font_color", T.WARNING)
        v.add_child(req)
    return panel

func _prereqs_met(node_id: String) -> bool:
    if not prereqs.has(node_id):
        return true
    for req_id in prereqs[node_id]:
        if not bool(RunState.allocated_talents.get(String(req_id), false)):
            return false
    return true

func _allocate(node_id: String) -> void:
    if RunState.talent_points <= 0: return
    if RunState.allocated_talents.get(node_id, false): return
    if not _prereqs_met(node_id): return
    RunState.allocated_talents[node_id] = true
    RunState.talent_points -= 1
    SfxBus.play("perk_pick", -2.0)
    _refresh()

func _on_close() -> void:
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
