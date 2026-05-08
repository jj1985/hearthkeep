extends Node

# Dynamic music director.
# Layers:
#   exploration -> low intensity ambient
#   tension     -> enemies in sight
#   combat      -> active fight
#   boss        -> dragon / warchief
# Crossfades between layers using AudioStreamPlayer with bus routing.
# In prototype, we synthesize layered tones procedurally so the demo is not
# silent; replacing the streams with licensed Kevin MacLeod tracks is a
# drop-in change documented in audio/AUDIO_MANIFEST.csv.

enum Layer { SILENT, EXPLORATION, TENSION, COMBAT, BOSS }

var current_layer: int = Layer.SILENT
var players: Dictionary = {}
var fade_in_time: float = 1.5
var fade_out_time: float = 1.0

func _ready() -> void:
    for layer in [Layer.EXPLORATION, Layer.TENSION, Layer.COMBAT, Layer.BOSS]:
        var p := AudioStreamPlayer.new()
        p.stream = _make_layer_stream(layer)
        p.volume_db = -80.0
        p.bus = "Master"
        p.autoplay = false
        add_child(p)
        players[layer] = p

func set_layer(layer: int) -> void:
    if layer == current_layer:
        return
    var prev: int = current_layer
    current_layer = layer
    if prev != Layer.SILENT and players.has(prev):
        var p_old: AudioStreamPlayer = players[prev]
        var tw := create_tween()
        tw.tween_property(p_old, "volume_db", -80.0, fade_out_time)
        tw.tween_callback(p_old.stop)
    if layer != Layer.SILENT and players.has(layer):
        var p_new: AudioStreamPlayer = players[layer]
        if not p_new.playing:
            p_new.volume_db = -80.0
            p_new.play()
        var v_target: float = -16.0 + Settings.music_volume * 16.0
        var tw2 := create_tween()
        tw2.tween_property(p_new, "volume_db", v_target, fade_in_time)
    EventBus.music_layer_request.emit(layer)

func _make_layer_stream(layer: int) -> AudioStreamWAV:
    var sample_rate := 22050
    var seconds := 16
    var frames := sample_rate * seconds
    var data := PackedByteArray()
    data.resize(frames * 2)
    var freqs: Array
    match layer:
        Layer.EXPLORATION: freqs = [110.0, 165.0, 220.0]
        Layer.TENSION:     freqs = [98.0, 196.0, 294.0]
        Layer.COMBAT:      freqs = [82.0, 123.0, 196.0, 246.0]
        Layer.BOSS:        freqs = [55.0, 82.0, 110.0, 165.0]
        _: freqs = [220.0]
    for i in range(frames):
        var t := float(i) / sample_rate
        var v := 0.0
        for f in freqs:
            v += sin(t * float(f) * TAU) * 0.18 / float(freqs.size())
        # Slow envelope swell
        var env: float = 0.5 + 0.5 * sin(t * 0.05 * TAU)
        v *= env
        var s := int(clamp(v * 32767.0, -32768.0, 32767.0))
        data[i * 2] = s & 0xff
        data[i * 2 + 1] = (s >> 8) & 0xff
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sample_rate
    wav.stereo = false
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.loop_begin = 0
    wav.loop_end = frames
    wav.data = data
    return wav

func cue_combat(active: bool) -> void:
    if active:
        if current_layer < Layer.COMBAT:
            set_layer(Layer.COMBAT)
    else:
        if current_layer == Layer.COMBAT:
            set_layer(Layer.EXPLORATION)

func cue_boss(active: bool) -> void:
    if active:
        set_layer(Layer.BOSS)
    elif current_layer == Layer.BOSS:
        set_layer(Layer.EXPLORATION)
