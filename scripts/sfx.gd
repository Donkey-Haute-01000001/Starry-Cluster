class_name Sfx
extends RefCounted
## Paper and dock foley (synthesized by tools/make_sounds.py). Fire and forget:
## Sfx.play("stamp"). Missing sounds are ignored.

static var _cache := {}


static func stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := "res://sounds/%s.wav" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


static func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := stream(name)
	var tree := Engine.get_main_loop() as SceneTree
	if s == null or tree == null or tree.root == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	tree.root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Voices playing per sound, so a turret's stream of shots can't pile up.
static var _voices := {}
const VOICE_CAP := {"turret": 6, "flak": 5, "hit_hull": 4, "hit_shield": 4, "cannon": 6}


## A sound out in the world: louder near the camera, panned to its side.
static func play_at(name: String, pos: Vector2, volume_db := 0.0, pitch := 1.0) -> void:
	var s := stream(name)
	var tree := Engine.get_main_loop() as SceneTree
	if s == null or tree == null or tree.current_scene == null:
		return
	var n: int = _voices.get(name, 0)
	if n >= int(VOICE_CAP.get(name, 8)):
		return
	_voices[name] = n + 1
	var p := AudioStreamPlayer2D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.max_distance = 2400.0
	p.attenuation = 1.6
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.global_position = pos
	tree.current_scene.add_child(p)
	p.finished.connect(func():
		_voices[name] = maxi(int(_voices.get(name, 1)) - 1, 0)
		p.queue_free())
	p.play()


## A looping ambience player; the caller adds it to the tree.
static func loop(name: String, volume_db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := stream(name)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	p.stream = s
	p.volume_db = volume_db
	p.autoplay = s != null
	return p
