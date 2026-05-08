extends Node

# Tracks viewport orientation/aspect and emits a signal when the layout
# bucket changes (portrait phone, landscape phone, tablet portrait, tablet
# landscape, desktop). HUDs subscribe and reflow.

enum Orient { LANDSCAPE_PHONE, PORTRAIT_PHONE, LANDSCAPE_TABLET, PORTRAIT_TABLET, DESKTOP }

signal orientation_changed(orient)

var current: int = Orient.DESKTOP
var last_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
    set_process(true)
    _evaluate(true)
    var vp := get_viewport()
    if vp != null:
        vp.size_changed.connect(_on_size_changed)

func _process(_delta: float) -> void:
    pass

func _on_size_changed() -> void:
    _evaluate(false)

func _evaluate(force: bool) -> void:
    var vp := get_viewport()
    if vp == null: return
    var s: Vector2i = vp.get_visible_rect().size
    if not force and s == last_size:
        return
    last_size = s
    var aspect: float = float(s.x) / max(1.0, float(s.y))
    var min_dim: int = min(s.x, s.y)
    var on_mobile: bool = OS.has_feature("mobile") or OS.has_feature("web")
    var is_tablet: bool = min_dim >= 600 if on_mobile else false
    var bucket: int
    if not on_mobile:
        bucket = Orient.DESKTOP
    elif aspect >= 1.0:
        bucket = Orient.LANDSCAPE_TABLET if is_tablet else Orient.LANDSCAPE_PHONE
    else:
        bucket = Orient.PORTRAIT_TABLET if is_tablet else Orient.PORTRAIT_PHONE
    if bucket != current or force:
        current = bucket
        orientation_changed.emit(current)

func is_portrait() -> bool:
    return current == Orient.PORTRAIT_PHONE or current == Orient.PORTRAIT_TABLET

func is_tablet() -> bool:
    return current == Orient.LANDSCAPE_TABLET or current == Orient.PORTRAIT_TABLET

func name_of(bucket: int = -1) -> String:
    if bucket < 0: bucket = current
    match bucket:
        Orient.LANDSCAPE_PHONE: return "landscape-phone"
        Orient.PORTRAIT_PHONE: return "portrait-phone"
        Orient.LANDSCAPE_TABLET: return "landscape-tablet"
        Orient.PORTRAIT_TABLET: return "portrait-tablet"
        Orient.DESKTOP: return "desktop"
    return "?"
