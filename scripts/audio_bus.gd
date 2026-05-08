extends Node

# Lightweight SFX bus. Plays one-shot AudioStreamPlayer nodes.
# Real assets land in /audio/ — for prototype we generate beeps procedurally so the demo isn't silent.

var _generated: Dictionary = {}

func _ready() -> void:
    _generated["hit"] = _make_tone(440.0, 0.06)
    _generated["crit"] = _make_tone(880.0, 0.10)
    _generated["pickup"] = _make_tone(660.0, 0.05)
    _generated["potion"] = _make_tone(550.0, 0.12)
    _generated["levelup"] = _make_tone(990.0, 0.25)
    _generated["dragon_roar"] = _make_tone(120.0, 0.6)

func play(name: String, volume_db: float = -6.0) -> void:
    if not _generated.has(name):
        return
    var p := AudioStreamPlayer.new()
    p.stream = _generated[name]
    p.volume_db = volume_db
    add_child(p)
    p.play()
    p.finished.connect(p.queue_free)

func _make_tone(freq: float, dur: float) -> AudioStreamWAV:
    var sample_rate := 22050
    var sample_count := int(sample_rate * dur)
    var data := PackedByteArray()
    data.resize(sample_count * 2)
    for i in range(sample_count):
        var t := float(i) / sample_rate
        var env: float = clamp(1.0 - t / dur, 0.0, 1.0)
        var s: float = sin(t * freq * TAU) * env * 0.5
        var v := int(clamp(s * 32767.0, -32768.0, 32767.0))
        data[i * 2] = v & 0xff
        data[i * 2 + 1] = (v >> 8) & 0xff
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sample_rate
    wav.stereo = false
    wav.data = data
    return wav
