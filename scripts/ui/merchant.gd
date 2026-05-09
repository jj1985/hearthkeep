extends Control

# General Merchant — buy consumables (potions / scrolls / oils), sell
# loot from inventory, browse a buyback queue.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const STOCK := [
    {"id":"hp_potion",       "name":"HP Potion",        "price": 25, "tags":["potion","heal"], "kind":"consumable"},
    {"id":"mp_potion",       "name":"MP Potion",        "price": 25, "tags":["potion","mana"], "kind":"consumable"},
    {"id":"hp_potion_lg",    "name":"Large HP Potion",  "price": 90, "tags":["potion","heal"], "kind":"consumable"},
    {"id":"mp_potion_lg",    "name":"Large MP Potion",  "price": 90, "tags":["potion","mana"], "kind":"consumable"},
    {"id":"haste",           "name":"Scroll of Haste",  "price":120, "tags":["scroll","buff"], "kind":"buff_scroll"},
    {"id":"blessing_might",  "name":"Scroll of Might",  "price":120, "tags":["scroll","buff"], "kind":"buff_scroll"},
    {"id":"whetstone_flame", "name":"Whetstone of Flame","price":150, "tags":["oil","fire"],   "kind":"weapon_buff"},
    {"id":"frost_oil",       "name":"Frost Oil",        "price":150, "tags":["oil","frost"],   "kind":"weapon_buff"},
    {"id":"lightning_coat",  "name":"Lightning Coating","price":180, "tags":["oil","lightning"],"kind":"weapon_buff"},
    {"id":"poison_vial",     "name":"Poison Vial",      "price":140, "tags":["oil","poison"],  "kind":"weapon_buff"},
    {"id":"holy_oil",        "name":"Holy Oil",         "price":160, "tags":["oil","holy"],    "kind":"weapon_buff"},
]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var balance: Label = $SafeArea/V/Balance
@onready var tab_buy: Button = $SafeArea/V/Tabs/Buy
@onready var tab_sell: Button = $SafeArea/V/Tabs/Sell
@onready var tab_buyback: Button = $SafeArea/V/Tabs/Buyback
@onready var pane: VBoxContainer = $SafeArea/V/Scroll/Pane
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var current_tab: String = "buy"

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "BREN'S COUNTER"
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(close_btn)
    close_btn.pressed.connect(_on_close)
    for b in [tab_buy, tab_sell, tab_buyback]:
        UiAnim_.bind_press_feedback(b)
    tab_buy.pressed.connect(_select_tab.bind("buy"))
    tab_sell.pressed.connect(_select_tab.bind("sell"))
    tab_buyback.pressed.connect(_select_tab.bind("buyback"))
    _select_tab("buy")

func _select_tab(tab: String) -> void:
    current_tab = tab
    UiStyle_.apply_secondary(tab_buy)
    UiStyle_.apply_secondary(tab_sell)
    UiStyle_.apply_secondary(tab_buyback)
    if tab == "buy":   UiStyle_.apply_primary(tab_buy)
    if tab == "sell":  UiStyle_.apply_primary(tab_sell)
    if tab == "buyback": UiStyle_.apply_primary(tab_buyback)
    _refresh()

func _refresh() -> void:
    balance.text = "Gold:  %d" % GameState.gold
    balance.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    balance.add_theme_color_override("font_color", T.PRIMARY)
    for c in pane.get_children():
        c.queue_free()
    match current_tab:
        "buy":     _populate_buy()
        "sell":    _populate_sell()
        "buyback": _populate_buyback()

func _populate_buy() -> void:
    for entry in STOCK:
        pane.add_child(_buy_row(entry))

func _buy_row(entry: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 12)
    panel.add_child(h)
    var label := Label.new()
    label.text = String(entry["name"])
    label.add_theme_font_size_override("font_size", T.FS_TITLE_MD)
    label.add_theme_color_override("font_color", T.ON_SURFACE)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(label)
    var price_label := Label.new()
    price_label.text = "%d g" % int(entry["price"])
    price_label.add_theme_color_override("font_color", T.PRIMARY)
    h.add_child(price_label)
    var btn := Button.new()
    btn.text = "BUY"
    btn.custom_minimum_size = Vector2(96, 48)
    var affordable: bool = GameState.gold >= int(entry["price"])
    UiStyle_.apply_primary(btn) if affordable else UiStyle_.apply_secondary(btn)
    btn.disabled = not affordable
    if affordable:
        UiAnim_.bind_press_feedback(btn)
        btn.pressed.connect(_buy.bind(entry))
    h.add_child(btn)
    return panel

func _buy(entry: Dictionary) -> void:
    if GameState.gold < int(entry["price"]):
        return
    GameState.add_gold(-int(entry["price"]))
    SfxBus.play("pickup", -3.0)
    var kind: String = String(entry["kind"])
    # Instant-consume buff scrolls and weapon buffs — they apply now,
    # don't sit in inventory waiting for a chest UI use button.
    if kind == "buff_scroll":
        BuffSystem.apply(String(entry["id"]), BuffSystem.SOURCE_CONSUMABLE)
        EventBus.floating_text.emit("APPLIED  %s" % entry["name"], Vector2.ZERO, T.SUCCESS)
        _refresh()
        return
    if kind == "weapon_buff":
        BuffSystem.apply_weapon_buff(String(entry["id"]))
        EventBus.floating_text.emit("WEAPON COATED — %s" % entry["name"], Vector2.ZERO, T.SECONDARY)
        _refresh()
        return
    var item := {
        "id": entry["id"],
        "name": entry["name"],
        "tags": entry["tags"].duplicate(),
        "rarity": 0,
        "ilvl": 1,
        "kind": kind,
        "stack": 1,
    }
    ChestManager.deposit(item)
    EventBus.floating_text.emit("BOUGHT  %s" % entry["name"], Vector2.ZERO, T.SUCCESS)
    _refresh()

func _populate_sell() -> void:
    var bag: Array = Inventory.bag.duplicate()
    if bag.is_empty():
        var empty := Label.new()
        empty.text = "Nothing in your pack to sell."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        pane.add_child(empty)
        return
    for it in bag:
        pane.add_child(_sell_row(it))

func _sell_row(item: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 12)
    panel.add_child(h)
    var label := Label.new()
    label.text = String(item.get("name", "?"))
    label.add_theme_font_size_override("font_size", T.FS_TITLE_MD)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(label)
    var price: int = VendorSystem.sell_value(item)
    var price_label := Label.new()
    price_label.text = "%d g" % price
    price_label.add_theme_color_override("font_color", T.PRIMARY)
    h.add_child(price_label)
    var btn := Button.new()
    btn.text = "SELL"
    btn.custom_minimum_size = Vector2(96, 48)
    UiStyle_.apply_primary(btn)
    UiAnim_.bind_press_feedback(btn)
    btn.pressed.connect(_sell.bind(item))
    h.add_child(btn)
    return panel

func _sell(item: Dictionary) -> void:
    var price: int = VendorSystem.sell(item)
    GameState.add_gold(price)
    Inventory.bag.erase(item)
    SfxBus.play("pickup", -2.0)
    EventBus.floating_text.emit("SOLD  +%d g" % price, Vector2.ZERO, T.PRIMARY)
    _refresh()

func _populate_buyback() -> void:
    if VendorSystem.buyback.is_empty():
        var empty := Label.new()
        empty.text = "Buyback queue empty."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        pane.add_child(empty)
        return
    for it in VendorSystem.buyback:
        pane.add_child(_buyback_row(it))

func _buyback_row(item: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 12)
    panel.add_child(h)
    var label := Label.new()
    label.text = String(item.get("name", "?"))
    label.add_theme_font_size_override("font_size", T.FS_TITLE_MD)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(label)
    var price: int = VendorSystem.sell_value(item)
    var price_label := Label.new()
    price_label.text = "%d g" % price
    price_label.add_theme_color_override("font_color", T.PRIMARY)
    h.add_child(price_label)
    var btn := Button.new()
    btn.text = "BUY BACK"
    btn.custom_minimum_size = Vector2(120, 48)
    var affordable: bool = GameState.gold >= price
    UiStyle_.apply_primary(btn) if affordable else UiStyle_.apply_secondary(btn)
    btn.disabled = not affordable
    if affordable:
        UiAnim_.bind_press_feedback(btn)
        btn.pressed.connect(_buyback.bind(item, price))
    h.add_child(btn)
    return panel

func _buyback(item: Dictionary, price: int) -> void:
    if not VendorSystem.buy_back(item):
        return
    GameState.add_gold(-price)
    ChestManager.deposit(item)
    SfxBus.play("pickup", -2.0)
    EventBus.floating_text.emit("RECLAIMED  %s" % item.get("name", "?"), Vector2.ZERO, T.PRIMARY)
    _refresh()

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
