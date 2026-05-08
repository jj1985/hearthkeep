extends Control

# Chest / inventory view per spec §10.
# Compact: 5 cols × 64 dp cells; medium: 7 × 72; expanded: 10 × 80.
# Cells: surface fill, 1-px outline, rarity 2-px BOTTOM stripe on occupied
# cells. Sort/filter chips along top, search bar above grid.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const RARITY_NAMES := ["common", "uncommon", "rare", "epic", "legendary", "artifact"]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var title_label: Label = $SafeArea/V/Header/Title
@onready var count_label: Label = $SafeArea/V/Header/Count
@onready var sort_btn: OptionButton = $SafeArea/V/Filters/SortBtn
@onready var filter_chips: HBoxContainer = $SafeArea/V/Filters/ChipsScroll/Chips
@onready var search_edit: LineEdit = $SafeArea/V/SearchBar
@onready var grid: GridContainer = $SafeArea/V/Scroll/Grid
@onready var empty_state: Label = $SafeArea/V/EmptyState
@onready var sell_all_btn: Button = $SafeArea/V/Footer/SellAllBtn
@onready var close_btn: Button = $SafeArea/V/Footer/CloseBtn

var current_chest: String = ""
var on_close: Callable
var rarity_filter: int = -1                 # -1 = all
var rarity_chip_buttons: Array[Button] = []
var selected_card: PanelContainer = null
var info_popover: PanelContainer = null

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    _apply_typography()
    _build_filter_chips()
    sort_btn.add_item("By Rarity", 0)
    sort_btn.add_item("By Item Level", 1)
    sort_btn.add_item("By Name", 2)
    sort_btn.add_item("By Sell Value", 3)
    sort_btn.item_selected.connect(_refresh)
    search_edit.text_changed.connect(_on_search)
    sell_all_btn.pressed.connect(_sell_all_junk)
    close_btn.pressed.connect(_on_close)
    UiAnim_.bind_press_feedback(sell_all_btn)
    UiAnim_.bind_press_feedback(close_btn)
    if Engine.has_singleton("OrientationMgr"):
        OrientationMgr.bucket_changed.connect(_on_bucket_changed)
    _apply_bucket()

func _apply_typography() -> void:
    title_label.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    title_label.add_theme_color_override("font_color", T.PRIMARY)
    count_label.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
    count_label.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    empty_state.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    empty_state.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    UiStyle_.apply_secondary(close_btn)
    UiStyle_.apply_primary(sell_all_btn)

func _on_bucket_changed(_b) -> void:
    _apply_bucket()

func _apply_bucket() -> void:
    var cols: int = 5
    var cell: int = 64
    if Engine.has_singleton("OrientationMgr"):
        match OrientationMgr.bucket:
            OrientationMgr.Bucket.MEDIUM:
                cols = 7
                cell = 72
            OrientationMgr.Bucket.EXPANDED:
                cols = 10
                cell = 80
    grid.columns = cols
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    grid.set_meta("cell_size", cell)

func _build_filter_chips() -> void:
    rarity_chip_buttons.clear()
    var chip_def := [
        ["All", -1],
        ["Common", 0], ["Uncommon", 1], ["Rare", 2],
        ["Epic", 3], ["Legendary", 4], ["Artifact", 5],
    ]
    for entry in chip_def:
        var b := Button.new()
        b.text = String(entry[0]).to_upper()
        b.set_meta("rarity", int(entry[1]))
        b.add_theme_font_size_override("font_size", T.FS_LABEL_MD)
        b.add_theme_color_override("font_color", T.ON_SURFACE)
        b.add_theme_color_override("font_pressed_color", T.ON_PRIMARY)
        var sb := UiStyle_.chip()
        b.add_theme_stylebox_override("normal", sb)
        b.add_theme_stylebox_override("hover", sb)
        b.add_theme_stylebox_override("pressed", _chip_active())
        UiAnim_.bind_press_feedback(b, 0.95)
        b.pressed.connect(_on_filter_chip.bind(int(entry[1])))
        filter_chips.add_child(b)
        rarity_chip_buttons.append(b)
    _refresh_chip_states()

func _chip_active() -> StyleBoxFlat:
    var sb := UiStyle_.chip()
    sb.bg_color = T.PRIMARY
    sb.border_color = T.PRIMARY
    return sb

func _on_filter_chip(rarity: int) -> void:
    rarity_filter = rarity
    _refresh_chip_states()
    _refresh(sort_btn.selected)

func _refresh_chip_states() -> void:
    for b in rarity_chip_buttons:
        var is_active: bool = int(b.get_meta("rarity")) == rarity_filter
        b.add_theme_color_override("font_color", T.ON_PRIMARY if is_active else T.ON_SURFACE)
        var sb := _chip_active() if is_active else UiStyle_.chip()
        b.add_theme_stylebox_override("normal", sb)
        b.add_theme_stylebox_override("hover", sb)

func show_chest(chest_id: String, cb: Callable) -> void:
    current_chest = chest_id
    on_close = cb
    var lbl: String = _chest_label(chest_id)
    title_label.text = lbl.to_upper()
    sell_all_btn.visible = chest_id == "junk"
    _refresh(0)

func _chest_label(id: String) -> String:
    for d in ChestManager.CHEST_DEFS:
        if (d as Dictionary)["id"] == id:
            return str((d as Dictionary)["name"])
    return id

func _refresh(_idx: int = 0) -> void:
    for c in grid.get_children():
        c.queue_free()
    var by: String = ["rarity", "ilvl", "name", "value"][sort_btn.selected]
    var items: Array = ChestManager.sort_chest(current_chest, by)
    var q: String = search_edit.text.to_lower()
    if q != "":
        items = items.filter(func(it):
            return str((it as Dictionary).get("name","")).to_lower().contains(q))
    if rarity_filter >= 0:
        items = items.filter(func(it):
            return int((it as Dictionary).get("rarity", 0)) == rarity_filter)
    count_label.text = "%d items" % items.size()
    if items.is_empty():
        empty_state.visible = true
        empty_state.text = "Even crows pick at richer lots."
        return
    empty_state.visible = false
    for it in items:
        grid.add_child(_make_cell(it))

func _make_cell(item: Dictionary) -> Control:
    var cell_size: int = int(grid.get_meta("cell_size", 64))
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(cell_size, cell_size)
    var rarity: int = clamp(int(item.get("rarity", 0)), 0, RARITY_NAMES.size() - 1)
    var sb := StyleBoxFlat.new()
    sb.bg_color = T.SURFACE
    sb.border_color = T.OUTLINE
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(T.RADIUS_SM)
    card.add_theme_stylebox_override("panel", sb)

    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 0)
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.add_child(v)

    var label := Label.new()
    label.text = _short_name(item.get("name", "?"))
    label.add_theme_font_size_override("font_size", T.FS_LABEL_SM)
    label.add_theme_color_override("font_color", T.rarity(RARITY_NAMES[rarity]))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(label)

    var stripe := ColorRect.new()
    stripe.custom_minimum_size = Vector2(0, 2)
    stripe.color = T.rarity(RARITY_NAMES[rarity])
    v.add_child(stripe)

    card.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            _show_info(item, card)
        elif event is InputEventScreenTouch and event.pressed:
            _show_info(item, card))
    return card

func _short_name(s: String) -> String:
    if s.length() <= 18:
        return s
    return s.substr(0, 16) + "…"

func _show_info(item: Dictionary, anchor: PanelContainer) -> void:
    if info_popover != null and is_instance_valid(info_popover):
        info_popover.queue_free()
    var pop := PanelContainer.new()
    pop.add_theme_stylebox_override("panel", UiStyle_.panel_modal())
    pop.custom_minimum_size = Vector2(220, 0)
    var v := VBoxContainer.new()
    pop.add_child(v)
    var name_label := Label.new()
    name_label.text = String(item.get("name", "Item"))
    var rarity: int = clamp(int(item.get("rarity", 0)), 0, RARITY_NAMES.size() - 1)
    name_label.add_theme_color_override("font_color", T.rarity(RARITY_NAMES[rarity]))
    name_label.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    v.add_child(name_label)
    var sub := Label.new()
    var ilvl_str: String = "iLvl %d" % int(item.get("ilvl", 0))
    var value_str: String = "%dg" % int(VendorSystem.sell_value(item))
    sub.text = "%s · %s" % [ilvl_str, value_str]
    sub.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    sub.add_theme_font_size_override("font_size", T.FS_BODY_SM)
    v.add_child(sub)
    info_popover = pop
    add_child(pop)
    pop.position = anchor.global_position + Vector2(0, anchor.size.y + 4)
    UiAnim_.slide_up_in(pop, 12.0, UiAnim_.DUR_SM)
    var dismiss_timer := Timer.new()
    dismiss_timer.wait_time = 2.4
    dismiss_timer.one_shot = true
    add_child(dismiss_timer)
    dismiss_timer.timeout.connect(func():
        if is_instance_valid(pop):
            pop.queue_free()
        dismiss_timer.queue_free())
    dismiss_timer.start()

func _on_search(_t: String) -> void:
    _refresh(sort_btn.selected)

func _sell_all_junk() -> void:
    var junk: Array = ChestManager.get_chest("junk").duplicate()
    var result: Dictionary = VendorSystem.sell_all_junk(junk)
    for it in (result["items"] as Array):
        ChestManager.withdraw("junk", it)
    EventBus.floating_text.emit("Sold %d items for %dg" % [(result["items"] as Array).size(), result["gold"]],
        Vector2.ZERO, T.PRIMARY)
    _refresh(sort_btn.selected)

func _on_close() -> void:
    if on_close.is_valid():
        on_close.call()
