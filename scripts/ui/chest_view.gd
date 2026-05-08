extends Control

@onready var title: Label = $Panel/V/Title
@onready var sort_btn: OptionButton = $Panel/V/Header/SortBtn
@onready var search_edit: LineEdit = $Panel/V/Header/SearchEdit
@onready var grid: GridContainer = $Panel/V/Scroll/Grid
@onready var sell_all_btn: Button = $Panel/V/Footer/SellAllBtn
@onready var close_btn: Button = $Panel/V/Footer/CloseBtn

var current_chest: String = ""
var on_close: Callable

func _ready() -> void:
    sort_btn.add_item("By Rarity", 0)
    sort_btn.add_item("By Item Level", 1)
    sort_btn.add_item("By Name", 2)
    sort_btn.add_item("By Sell Value", 3)
    sort_btn.item_selected.connect(_refresh)
    search_edit.text_changed.connect(_on_search)
    sell_all_btn.pressed.connect(_sell_all_junk)
    close_btn.pressed.connect(_on_close)

func show_chest(chest_id: String, cb: Callable) -> void:
    current_chest = chest_id
    on_close = cb
    title.text = _chest_label(chest_id) + "  ·  " + str(ChestManager.chest_count(chest_id))
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
    if items.is_empty():
        var empty := Label.new()
        empty.text = "Adventure awaits…"
        empty.modulate = Color(0.6, 0.55, 0.5)
        grid.add_child(empty)
        return
    for it in items:
        grid.add_child(_make_item_card(it))

func _make_item_card(item: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(180, 80)
    var sb := StyleBoxFlat.new()
    var rarity: int = int(item.get("rarity", 0))
    sb.bg_color = Color(0.10, 0.08, 0.13, 0.95)
    sb.border_color = LootSystem.RARITY_COLORS[clamp(rarity, 0, LootSystem.RARITY_COLORS.size() - 1)]
    sb.border_width_left = 3
    sb.border_width_right = 3
    sb.border_width_top = 3
    sb.border_width_bottom = 3
    sb.corner_radius_top_left = 6
    sb.corner_radius_top_right = 6
    sb.corner_radius_bottom_left = 6
    sb.corner_radius_bottom_right = 6
    card.add_theme_stylebox_override("panel", sb)
    var v := VBoxContainer.new()
    card.add_child(v)
    var name := Label.new()
    name.text = str(item.get("name", "Item"))
    name.modulate = LootSystem.RARITY_COLORS[clamp(rarity, 0, LootSystem.RARITY_COLORS.size() - 1)]
    v.add_child(name)
    var sub := Label.new()
    if item.get("vendor_trash", false):
        sub.text = "Vendor: " + str(VendorSystem.sell_value(item)) + "g"
    else:
        sub.text = "iLvl " + str(item.get("ilvl", 0)) + "  ·  " + str(VendorSystem.sell_value(item)) + "g"
    sub.modulate = Color(0.75, 0.72, 0.65)
    v.add_child(sub)
    return card

func _on_search(_t: String) -> void:
    _refresh(sort_btn.selected)

func _sell_all_junk() -> void:
    var junk: Array = ChestManager.get_chest("junk").duplicate()
    var result: Dictionary = VendorSystem.sell_all_junk(junk)
    for it in (result["items"] as Array):
        ChestManager.withdraw("junk", it)
    title.text += "  ·  Sold " + str(result["gold"]) + "g"
    _refresh(sort_btn.selected)

func _on_close() -> void:
    if on_close.is_valid():
        on_close.call()
