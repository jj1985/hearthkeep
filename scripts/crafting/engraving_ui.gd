extends Control

# Engraving Bench UI. Different shape than the other wizards — picks an
# existing weapon/armor item from the Treasury, lets the player choose
# a script + type a label, then consumes gold.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var bg: ColorRect = $Bg
@onready var headline: Label = $SafeArea/V/Headline
@onready var balance: Label = $SafeArea/V/Balance
@onready var item_scroll: ScrollContainer = $SafeArea/V/ItemPicker/ItemScroll
@onready var item_list: VBoxContainer = $SafeArea/V/ItemPicker/ItemScroll/List
@onready var script_row: HFlowContainer = $SafeArea/V/ScriptRow
@onready var label_input: LineEdit = $SafeArea/V/LabelInput
@onready var preview_label: Label = $SafeArea/V/Preview
@onready var engrave_btn: Button = $SafeArea/V/Footer/Engrave
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var selected_item: Dictionary = {}
var selected_script: String = "plain"

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "ENGRAVING BENCH"
    balance.add_theme_color_override("font_color", T.PRIMARY)
    balance.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    preview_label.add_theme_color_override("font_color", T.ON_SURFACE)
    preview_label.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    UiStyle_.apply_primary(engrave_btn)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(engrave_btn)
    UiAnim_.bind_press_feedback(close_btn)
    engrave_btn.pressed.connect(_on_engrave)
    close_btn.pressed.connect(_on_close)
    label_input.text_changed.connect(func(_s): _refresh_preview())
    _populate_scripts()
    _populate_items()
    _refresh_preview()

func _populate_scripts() -> void:
    for c in script_row.get_children():
        c.queue_free()
    for s in Engraving.SCRIPTS:
        var b := Button.new()
        b.text = "%s\n%d g" % [String(s["name"]), int(s["cost"])]
        b.custom_minimum_size = Vector2(160, 56)
        UiStyle_.apply_secondary(b)
        UiAnim_.bind_press_feedback(b)
        b.set_meta("script_id", s["id"])
        b.pressed.connect(func():
            selected_script = String(s["id"])
            _populate_scripts()
            _refresh_preview())
        if String(s["id"]) == selected_script:
            UiStyle_.apply_primary(b)
        script_row.add_child(b)

func _populate_items() -> void:
    for c in item_list.get_children():
        c.queue_free()
    var items := []
    for chest_id in ["weapons", "armor", "trinkets"]:
        items.append_array(ChestManager.get_chest(chest_id))
    if items.is_empty():
        var empty := Label.new()
        empty.text = "Nothing in your Treasury to engrave."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        empty.add_theme_font_size_override("font_size", T.FS_BODY_LG)
        item_list.add_child(empty)
        return
    for it in items:
        item_list.add_child(_item_row(it))

func _item_row(item: Dictionary) -> Control:
    var b := Button.new()
    var existing: String = String(item.get("engraving", ""))
    b.text = "%s%s" % [String(item.get("name", "?")),
        ("  ✦ engraved" if existing != "" else "")]
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.custom_minimum_size = Vector2(0, 56)
    UiStyle_.apply_secondary(b)
    UiAnim_.bind_press_feedback(b)
    b.pressed.connect(func():
        selected_item = item
        _populate_items()
        _refresh_preview())
    if selected_item == item:
        UiStyle_.apply_primary(b)
    return b

func _refresh_preview() -> void:
    balance.text = "Gold:  %d  ·  Script cost:  %d" % [GameState.gold, Engraving.cost_for(selected_script)]
    if selected_item.is_empty():
        preview_label.text = "Pick an item from your Treasury."
        engrave_btn.disabled = true
        return
    var label: String = String(label_input.text)
    var script_name: String = ""
    for s in Engraving.SCRIPTS:
        if s["id"] == selected_script:
            script_name = String(s["name"])
            break
    var preview: String = "Engrave %s" % String(selected_item.get("name", "?"))
    if label != "":
        preview += " — \"%s\"" % label
    preview += "\nScript: %s  ·  cost %d g" % [script_name, Engraving.cost_for(selected_script)]
    preview_label.text = preview
    engrave_btn.disabled = GameState.gold < Engraving.cost_for(selected_script)

func _on_engrave() -> void:
    if selected_item.is_empty():
        return
    var label: String = String(label_input.text)
    var result: Dictionary = Engraving.engrave(selected_item, selected_script, label)
    if result.is_empty():
        EventBus.floating_text.emit("Not enough gold.", Vector2.ZERO, T.ERROR)
        return
    SfxBus.play("forge_strike", -2.0)
    EventBus.floating_text.emit("ENGRAVED:  %s" % String(result.get("name", "?")), Vector2.ZERO, T.PRIMARY)
    selected_item = {}
    label_input.text = ""
    _populate_items()
    _refresh_preview()

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
