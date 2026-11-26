extends Node
## The soundtrack: DavidKBD's Pink Bloom pack, shuffled, playing across every
## scene. Each new track fades in with a small credit at the top right.
## Tracks live in art/music (not in git, like the other packs).

const DIR := "res://art/music"
const VOLUME_DB := -9.0
const GAP := 3.0             ## seconds of quiet between tracks
const ARTIST := "DavidKBD"

var _player: AudioStreamPlayer
var _tracks: Array = []       ## [{path, title}]
var _order: Array = []
var _credit: Control
var _credit_text := ""
var _credit_t := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while docked (paused)
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	PlayerController.load_settings()   # makes the Music bus
	_player.bus = "Music"
	_player.finished.connect(func():
		await get_tree().create_timer(GAP).timeout
		next())
	add_child(_player)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_credit = Control.new()
	_credit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credit.draw.connect(_draw_credit)
	layer.add_child(_credit)
	_scan()
	if not _tracks.is_empty():
		next.call_deferred()


func _scan() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if not name.ends_with(".ogg"):
			continue
		var path := DIR + "/" + name
		if _tracks.any(func(t): return t["path"] == path):
			continue
		# "01_-_Pink_Bloom.ogg" -> "Pink Bloom"
		var title := name.get_basename()
		var cut := title.find("_-_")
		if cut >= 0:
			title = title.substr(cut + 3)
		_tracks.append({"path": path, "title": title.replace("_", " ")})


## Next track in a shuffled order; reshuffles when the list runs out.
func next() -> void:
	if _tracks.is_empty():
		return
	if _order.is_empty():
		_order = range(_tracks.size())
		_order.shuffle()
	var t: Dictionary = _tracks[_order.pop_front()]
	var stream: AudioStream = null
	if ResourceLoader.exists(t["path"]):
		stream = load(t["path"])
	else:
		stream = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(t["path"]))
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = false
	_player.stream = stream
	_player.volume_db = -40.0
	_player.play()
	create_tween().tween_property(_player, "volume_db", VOLUME_DB, 2.5)
	_credit_text = t["title"].to_upper()
	_credit_t = 0.0


func _process(delta: float) -> void:
	if _credit_t >= 0.0:
		_credit_t += delta
		if _credit_t > 8.0:
			_credit_t = -1.0
		_credit.queue_redraw()


## A small dark tag in the top right corner: track title, then the artist.
func _draw_credit() -> void:
	if _credit_t < 0.0 or Data.font_type_bold == null:
		return
	var a := clampf(_credit_t / 0.8, 0.0, 1.0) * clampf((8.0 - _credit_t) / 1.4, 0.0, 1.0)
	var vp := _credit.size
	var fb: Font = Data.font_type_bold
	var f: Font = Data.font_type
	var head := "NOW PLAYING"
	var line := "%s  ·  %s" % [_credit_text, ARTIST]
	var w := maxf(fb.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 30.0
	var slide := (1.0 - clampf(_credit_t / 0.5, 0.0, 1.0)) * 12.0
	var r := Rect2(Vector2(vp.x - w - 20 + slide, 4), Vector2(w, 34))
	_credit.draw_rect(r, Color(0.04, 0.045, 0.05, 0.85 * a))
	_credit.draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(1.0, 0.45, 0.7, a))
	_credit.draw_string(f, r.position + Vector2(14, 12), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.65, 0.7, a))
	_credit.draw_string(fb, r.position + Vector2(14, 28), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.92, 0.9, a))
