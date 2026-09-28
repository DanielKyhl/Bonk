extends Node
## Sound effects and music (autoload "Sound"). All audio is synthesized by
## tools/audio/ (sfx.py, music.py).
##
##   Sound.play("hit", pos)      # a one-shot, quieter the farther from the hero
##   Sound.music("vale")         # crossfades to a looping track ("" = silence)
##
## A pool of voices plays the one-shots. Each sound has a volume, a minimum
## gap between plays and a cap on copies at once, so a horde of hits stays
## a clatter rather than a roar.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 28
const HEAR_RANGE := 60.0      ## Meters: farther sounds are skipped.
const FALLOFF_DB := 0.35      ## dB lost per meter from the hero.
const FADE := 1.6             ## Music crossfade seconds.
const PAUSED_DUCK_DB := -8.0

## name: [volume dB, min seconds between plays, max copies at once, pitch jitter]
const SOUNDS := {
	"hit": [-15.0, 0.05, 3, 0.12], "crit": [-10.0, 0.08, 2, 0.08], "bone": [-13.0, 0.06, 3, 0.15],
	"swing": [-12.0, 0.1, 2, 0.08], "claw": [-13.0, 0.08, 2, 0.1], "throw": [-15.0, 0.08, 2, 0.1],
	"smite": [-14.0, 0.1, 2, 0.06], "fire": [-11.0, 0.15, 2, 0.06], "zap": [-12.0, 0.1, 2, 0.08],
	"chain": [-12.0, 0.12, 2, 0.06], "ice": [-13.0, 0.1, 2, 0.08], "slam": [-8.0, 0.15, 2, 0.05],
	"soul": [-13.0, 0.15, 2, 0.06], "skull": [-16.0, 0.1, 2, 0.12], "rift": [-12.0, 0.2, 2, 0.05],
	"jump": [-18.0, 0.05, 1, 0.08], "land": [-12.0, 0.08, 1, 0.08], "slide": [-14.0, 0.2, 1, 0.06],
	"stomp": [-8.0, 0.05, 2, 0.06], "launch": [-8.0, 0.3, 1, 0.03], "hurt": [-6.0, 0.1, 1, 0.08],
	"block": [-6.0, 0.2, 1, 0.03], "revive": [-4.0, 1.0, 1, 0.0],
	"gem": [-17.0, 0.03, 3, 0.0], "coin": [-14.0, 0.05, 2, 0.06], "heart": [-10.0, 0.2, 1, 0.0],
	"levelup": [-8.0, 0.5, 1, 0.0], "chest": [-6.0, 0.3, 1, 0.03], "item": [-8.0, 0.2, 1, 0.0],
	"legendary": [-5.0, 0.5, 1, 0.0], "toll": [-7.0, 1.0, 1, 0.0], "prayer": [-6.0, 1.0, 1, 0.0],
	"curse": [-5.0, 1.0, 1, 0.0], "boss_roar": [-3.0, 1.0, 1, 0.0], "nova": [-9.0, 0.3, 1, 0.05],
	"bolt": [-14.0, 0.15, 2, 0.08], "blink": [-7.0, 0.5, 1, 0.0], "boss_die": [-2.0, 1.0, 1, 0.0],
	"portal": [-5.0, 1.0, 1, 0.0], "death": [-3.0, 1.0, 1, 0.0],
	"click": [-10.0, 0.03, 2, 0.04], "hover": [-20.0, 0.03, 2, 0.06],
}

## The hero, for distance falloff (set by the run; null in menus).
var listener: Node3D

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_sound: Array[String] = []
var _next := 0
var _last := {}
var _music: Array[AudioStreamPlayer] = []
var _music_on := 0
var _music_id := ""
var _music_streams := {}
var _duck := 0.0
var _tweens: Array[Tween] = [null, null]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id: String in SOUNDS:
		for ext in [".wav", ".ogg"]:
			if ResourceLoader.exists(SFX_DIR + id + ext):
				_streams[id] = load(SFX_DIR + id + ext)
				break
	for k in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
		_voice_sound.append("")
	for k in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	# Every button in the game clicks.
	get_tree().node_added.connect(_on_node_added)


## Plays a one-shot. `at` (a Vector3 or null) fades it with distance from
## the hero; pitch scales the playback speed; vol_db adds to its volume.
func play(id: String, at: Variant = null, pitch := 1.0, vol_db := 0.0) -> void:
	var s: AudioStream = _streams.get(id)
	if s == null:
		return
	var cfg: Array = SOUNDS[id]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -10.0)) < cfg[1]:
		return
	var vol: float = cfg[0] + vol_db
	if at != null and listener != null and is_instance_valid(listener):
		var d := (at as Vector3).distance_to(listener.global_position)
		if d > HEAR_RANGE:
			return
		vol -= d * FALLOFF_DB
	var copies := 0
	for k in VOICES:
		if _voice_sound[k] == id and _voices[k].playing:
			copies += 1
	if copies >= cfg[2]:
		return
	_last[id] = now
	# Take a free voice, else the next one round-robin.
	var v := -1
	for k in VOICES:
		var i := (_next + k) % VOICES
		if not _voices[i].playing:
			v = i
			break
	if v < 0:
		v = _next
	_next = (v + 1) % VOICES
	var p := _voices[v]
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-cfg[3], cfg[3])))
	p.play()
	_voice_sound[v] = id


## Crossfades to a looping track; "" fades the music out.
func music(id: String) -> void:
	if id == _music_id:
		return
	_music_id = id
	_fade(_music_on, -80.0, true)
	if id == "":
		return
	var stream: AudioStream = _music_streams.get(id)
	if stream == null:
		var path := MUSIC_DIR + id + ".ogg"
		if not ResourceLoader.exists(path):
			return
		stream = load(path)
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_music_streams[id] = stream
	_music_on = 1 - _music_on
	var p := _music[_music_on]
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	_fade(_music_on, 0.0, false)


func current_music() -> String:
	return _music_id


func _fade(k: int, to_db: float, stop_after: bool) -> void:
	var p := _music[k]
	if _tweens[k] != null and _tweens[k].is_valid():
		_tweens[k].kill()
	var tw := create_tween()
	_tweens[k] = tw
	tw.tween_property(p, "volume_db", to_db, FADE).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)


func _process(delta: float) -> void:
	# Duck the music while the game is paused (menus, level-ups).
	var want := PAUSED_DUCK_DB if get_tree().paused else 0.0
	_duck = move_toward(_duck, want, delta * 20.0)
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(Game.music_volume, 0.0001)) + _duck)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		b.pressed.connect(func(): play("click"))
		b.mouse_entered.connect(func(): if not b.disabled: play("hover"))
