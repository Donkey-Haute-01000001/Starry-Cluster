extends RefCounted
## Katana Zero-style lines: people, places, powers, money and threats light up
## in neon as you read; writers add [shake] [wave] [slow] [shine], [red] [gold] [green] by hand.
## Lines type out a word at a time, with a beat after each sentence.
## Use: var p := Neon.parse(text); Neon.draw(self, font, pos, p, width, size, col, a, age)

const RATE := 55.0             ## base characters per second; `pace` scales it
## Text speed from Settings: the multiple of RATE everything types at.
## Times in a parsed line stay in base units; duration/words_at/draw scale them.
const SPEEDS := [["Slow", 14.0], ["Normal", 20.0], ["Fast", 35.0], ["Instant", 0.0]]
static var pace := 20.0 / RATE
const SENTENCE_PAUSE := 0.28
const COMMA_PAUSE := 0.1
const SHAKE := 1
const WAVE := 2
const SLOW := 4
const SHINE := 8              ## a glint sweeps the word, and it glows even on paper

static var _cache := {}
static var _rules: Array = []
static var _rules_key := "-"
static var _tag_re: RegEx = null
static var _cr_re: RegEx = null


## Text with the tags taken out, for logs and plain print.
static func plain(text: String) -> String:
	return str(parse(text)["text"])


## The parsed line: plain text, a kind and effects per character, words and
## the moment each word appears.
static func parse(text: String) -> Dictionary:
	_refresh_rules()
	if _cache.has(text):
		return _cache[text]
	if _cache.size() > 400:
		_cache.clear()
	if _tag_re == null:
		_tag_re = RegEx.create_from_string("\\[(/?)(shake|wave|red|gold|green|slow|shine)\\]")
		_cr_re = RegEx.create_from_string("\\d[\\d,]*\\s(?:cr|credits)\\b|\\b\\d{1,3}(?:,\\d{3})+\\b")
	# Tags first: strip them, remember which characters they cover.
	var out := ""
	var fx := PackedInt32Array()
	var kind: Array = []
	var cur_fx := 0
	var tag_kind := ""
	var i := 0
	for m in _tag_re.search_all(text):
		var chunk := text.substr(i, m.get_start() - i)
		for c in chunk:
			out += c
			fx.append(cur_fx)
			kind.append(tag_kind)
		var close := m.get_string(1) == "/"
		match m.get_string(2):
			"shake": cur_fx = (cur_fx & ~SHAKE) if close else (cur_fx | SHAKE)
			"wave": cur_fx = (cur_fx & ~WAVE) if close else (cur_fx | WAVE)
			"slow": cur_fx = (cur_fx & ~SLOW) if close else (cur_fx | SLOW)
			"shine": cur_fx = (cur_fx & ~SHINE) if close else (cur_fx | SHINE)
			"red": tag_kind = "" if close else "threats"
			"gold": tag_kind = "" if close else "gold"
			"green": tag_kind = "" if close else "envy"
		i = m.get_end()
	for c in text.substr(i):
		out += c
		fx.append(cur_fx)
		kind.append(tag_kind)
	# Then the world's words, longest first, never overlapping.
	for r in _rules:
		_mark(out, kind, r[0], r[1], r[2])
	for m in _cr_re.search_all(out):
		_fill(kind, m.get_start(), m.get_end(), "credits")
	# Words and when each one types in.
	var words: Array = []   ## [start, end]
	var times := PackedFloat32Array()
	var t := 0.0
	var w0 := -1
	for k in out.length() + 1:
		var sp := k == out.length() or out[k] == " " or out[k] == "\n"
		if not sp and w0 < 0:
			w0 = k
		elif sp and w0 >= 0:
			words.append([w0, k])
			times.append(t)
			var rate := RATE * (0.3 if fx[w0] & SLOW else 1.0)
			t += float(k - w0) / rate
			var last := out[k - 1]
			if k < out.length():
				if last in [".", "?", "!", "…", "—"]:
					t += SENTENCE_PAUSE * (2.0 if fx[w0] & SLOW else 1.0)
				elif last in [",", ";", ":"]:
					t += COMMA_PAUSE
			w0 = -1
	var p := {"text": out, "kind": kind, "fx": fx, "words": words, "times": times, "dur": t}
	_cache[text] = p
	return p


## Seconds until the whole line has typed in.
static func duration(p: Dictionary) -> float:
	return float(p["dur"]) / pace


## Set the text speed by its index in SPEEDS.
static func set_speed(i: int) -> void:
	var cps: float = SPEEDS[clampi(i, 0, SPEEDS.size() - 1)][1]
	pace = 1e4 if cps <= 0.0 else cps / RATE


## How many words are showing `age` seconds in.
static func words_at(p: Dictionary, age: float) -> int:
	var n := 0
	age *= pace
	for t in p["times"]:
		if t <= age:
			n += 1
	return n


## The kind of word i ("" for plain words).
static func word_kind(p: Dictionary, i: int) -> String:
	var w: Array = p["words"][i]
	for k in range(w[0], w[1]):
		if p["kind"][k] != "":
			return p["kind"][k]
	return ""


static func color(kind: String) -> Color:
	if kind == "you":
		return you_color()
	if kind.begins_with("ship_"):
		kind = kind.substr(5)
	return Data.neon["colors"].get(kind, Color.WHITE)


## Your name takes the color of whoever you're loyal to.
static func you_color() -> Color:
	var side := str(Career.flags.get("side", ""))
	if side == "navy":
		return Data.neon["colors"]["navy"]
	if side == "tally":
		return Data.neon["colors"]["tally"]
	if Career.lane_rep() <= -2:
		return Data.neon["colors"]["threats"]
	return Color(0.93, 0.95, 0.98)


static func height(font: Font, p: Dictionary, width: float, size: int, max_lines := -1) -> float:
	var n: int = _layout(font, p, width, size).size()
	if max_lines > 0:
		n = mini(n, max_lines)
	return n * _line_h(font, size)


## Draw the line wrapped to `width`, top-left at `pos` (baseline of line 1 is
## pos.y + ascent). Only words that have typed in by `age` show. Returns height.
## paper=true: ink tones, no glow, for slips and printouts.
static func draw(ci: CanvasItem, font: Font, pos: Vector2, p: Dictionary, width: float, size: int,
		base: Color, alpha := 1.0, age := 1e9, paper := false, max_lines := -1, hits = null) -> float:
	var lay: Array = _layout(font, p, width, size)
	var lh := _line_h(font, size)
	var asc := font.get_ascent(size)
	var now := Time.get_ticks_msec() / 1000.0
	var text: String = p["text"]
	var sa := age * pace   ## age in the line's base time
	for li in lay.size():
		if max_lines > 0 and li >= max_lines:
			break
		for wi in lay[li]:
			if p["times"][wi] > sa:
				return (li + 1) * lh
			var w: Array = p["words"][wi]
			var x: float = lay[li][wi]
			var y := pos.y + li * lh + asc
			var dt: float = (sa - p["times"][wi]) / pace   ## real seconds since it landed
			# Runs of the same kind and effects inside the word.
			var k: int = w[0]
			while k < w[1]:
				var kd: String = p["kind"][k]
				var f: int = p["fx"][k]
				var e := k
				while e < w[1] and p["kind"][e] == kd and p["fx"][e] == f:
					e += 1
				var seg := text.substr(k, e - k)
				var col := base
				if kd != "":
					col = color(kd)
					if paper:
						col = col.darkened(0.38 if kd in ["gold", "envy"] else 0.55)
				var a := alpha
				# A neon tube kicking on: a stutter as the word lands.
				if kd != "" and dt < 0.3 and int(dt * 40.0) % 3 == 0:
					a *= 0.3
				col.a *= a
				var at := Vector2(pos.x + x, y)
				var rf := _run_font(kd, font, paper)
				var rs := _run_size(kd, size, paper)
				if hits != null and kd != "":
					var rw := rf.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x
					hits.append([Rect2(at + Vector2(0, -asc), Vector2(rw, lh)), kd, span(p, k)])
				if f & (SHAKE | WAVE | SHINE):
					var cx := at.x
					for ci2 in seg.length():
						var ch := seg[ci2]
						var off := Vector2.ZERO
						var gc := col
						var glow := kd != "" and not paper
						if f & SHINE:
							# A glint runs along the word every couple of seconds.
							# One slow pass about every 5 s, then rest.
							var sweep := (fmod(now, 5.0) / 1.4) * float(w[1] - w[0] + 6) - 3.0
							var d := absf(float(k + ci2 - w[0]) - sweep)
							var g := maxf(0.0, 1.0 - d / 2.5)
							gc = col.lightened(g * 0.3)
							glow = true
							if g > 0.0:
								ci.draw_string_outline(rf, Vector2(cx, at.y) + off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, rs, 6, Color(col, col.a * 0.4 * g))
						if f & SHAKE:
							if paper:
								# On paper: a short rattle every few seconds, then still.
								if fmod(now, 3.5) < 0.35:
									var ps := int(now * 14.0) + (k + ci2) * 7
									off += Vector2(sin(ps * 12.9898), cos(ps * 78.233)) * 0.9
							else:
								var s := int(now * 30.0) + (k + ci2) * 7
								off += Vector2(sin(s * 12.9898) , cos(s * 78.233)) * 1.4
						if f & WAVE:
							off.y += sin(now * 5.0 + (k + ci2) * 0.6) * 2.5
						_glyph(ci, rf, Vector2(cx, at.y) + off, ch, rs, gc, glow)
						cx += rf.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x
				else:
					if kd in ["credits", "dynasty"] and not paper:
						# Money hums: a fat slow-breathing halo.
						var hum := 0.75 + 0.25 * sin(now * 2.4)
						if kd == "dynasty":
							hum = 1.0
						ci.draw_string_outline(font, at, seg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 9, Color(col, col.a * 0.06 * hum))
					_glyph(ci, rf, at, seg, rs, col, kd != "" and not paper)
				x += rf.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x
				k = e
	var n := lay.size() if max_lines <= 0 else mini(lay.size(), max_lines)
	return n * lh


static func _glyph(ci: CanvasItem, font: Font, at: Vector2, s: String, size: int, col: Color, glow: bool) -> void:
	if glow:
		ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(col, col.a * 0.06))
		ci.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(col, col.a * 0.14))
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _line_h(font: Font, size: int) -> float:
	return font.get_height(size) + 2.0


## Lines of {word index: x}. Cached on the parsed line per width and size.
static func _layout(font: Font, p: Dictionary, width: float, size: int) -> Array:
	var key := "lay_%d_%d_%d" % [int(width), size, font.get_instance_id()]
	if p.has(key):
		return p[key]
	var text: String = p["text"]
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var lines: Array = [{}]
	var x := 0.0
	var prev_end := 0
	for wi in p["words"].size():
		var w: Array = p["words"][wi]
		var ww := _word_w(font, p, w, size)
		var newline := text.substr(prev_end, w[0] - prev_end).contains("\n")
		if newline or (x > 0.0 and x + ww > width):
			lines.append({})
			x = 0.0
		lines[-1][wi] = x
		x += ww + space
		prev_end = w[1]
	p[key] = lines
	return lines


## Tally's crew is written in his own hand.
static func _run_font(kd: String, font: Font, paper: bool) -> Font:
	return Data.font_hand if kd == "tally" and not paper and Data.font_hand else font


static func _run_size(kd: String, size: int, paper: bool) -> int:
	return int(round(size * 1.45)) if kd == "tally" and not paper and Data.font_hand else size


static func _word_w(font: Font, p: Dictionary, w: Array, size: int) -> float:
	var text: String = p["text"]
	var x := 0.0
	var k: int = w[0]
	while k < w[1]:
		var kd: String = p["kind"][k]
		var e := k
		while e < w[1] and p["kind"][e] == kd:
			e += 1
		x += _run_font(kd, font, false).get_string_size(text.substr(k, e - k), HORIZONTAL_ALIGNMENT_LEFT, -1, _run_size(kd, size, false)).x
		k = e
	return x


static func _fill(kind: Array, a: int, b: int, k: String) -> void:
	for i in range(a, b):
		if kind[i] != "":
			return
	for i in range(a, b):
		kind[i] = k


static func _mark(text: String, kind: Array, phrase: String, k: String, ci: bool) -> void:
	var from := 0
	while true:
		var at := text.findn(phrase, from) if ci else text.find(phrase, from)
		if at < 0:
			return
		var end := at + phrase.length()
		from = at + 1
		if at > 0 and _wordy(text[at - 1]):
			continue
		if end < text.length() and _wordy(text[end]) and not (text[end] == "s" and k == "threats"):
			continue
		# "Four of them" isn't the platform.
		if phrase == "Four" and text.substr(0, at).strip_edges(false, true).right(1) in ["", ".", "?", "!", "\""]:
			continue
		_fill(kind, at, end, k)


static func _wordy(c: String) -> bool:
	return c == "_" or c.to_upper() != c.to_lower() or c.is_valid_int()


static func _refresh_rules() -> void:
	var you: Array = [Career.player_name(), str(Career.pilot.get("name", "")), str(Career.pilot.get("rig", ""))]
	var key := "|".join(you)
	if key == _rules_key:
		return
	_rules_key = key
	_cache.clear()
	var list: Array = []
	for n in you:
		if n.length() >= 2 and n != "Unnamed rig" and n != "Unnamed":
			list.append([n, "you", false])
	for ph in Data.neon["ships"]:
		list.append([ph, "ship_" + str(Data.neon["ships"][ph][0]), false])
	for k in ["people", "places", "charter", "navy", "dynasty", "karabey", "league", "remnant", "faithful", "nomad", "tally"]:
		for ph in Data.neon[k]:
			list.append([ph, k, false])
	for s in Data.systems.values():
		list.append([str(s["name"]), "places", false])
	for s in Data.stations.values():
		list.append([str(s["name"]), "places", false])
		list.append([str(s.get("nick", "")).trim_prefix("the "), "places", false])
	for ph in Data.neon["threats"]:
		list.append([ph, "threats", true])
	list = list.filter(func(r): return str(r[0]).length() >= 2)
	list.sort_custom(func(a, b): return str(a[0]).length() > str(b[0]).length())
	_rules = list


## The line as BBCode, for RichTextLabels (the station comms board).
static func bbcode(text: String) -> String:
	var p := parse(text)
	var s: String = p["text"]
	var out := ""
	var cur := ""
	var url := false
	for i in s.length():
		var k: String = p["kind"][i]
		if k != cur:
			if cur != "":
				out += "[/color]"
				if url:
					out += "[/url]"
					url = false
			if k != "":
				var ph := span(p, i)
				if not link(k, ph).is_empty():
					out += "[url=%s|%s]" % [k, ph]
					url = true
				out += "[color=#%s]" % color(k).to_html(false)
			cur = k
		var c := s[i]
		out += "[lb]" if c == "[" else c
	if cur != "":
		out += "[/color]"
		if url:
			out += "[/url]"
	return out


## The whole highlighted phrase around character k ("Franz Kessler", not "Kessler").
static func span(p: Dictionary, k: int) -> String:
	var kd: String = p["kind"][k]
	var a := k
	var b := k
	while a > 0 and p["kind"][a - 1] == kd:
		a -= 1
	while b < p["kind"].size() and p["kind"][b] == kd:
		b += 1
	return str(p["text"]).substr(a, b - a)


## Where a highlighted phrase points in the journal: [tab, key] or [] if nowhere.
## Tabs: 1 people, 2 places, 3 powers.
static func link(kind: String, phrase: String) -> Array:
	var links: Dictionary = Data.neon["links"]
	if kind.begins_with("ship_"):
		# A ship opens its owner's page, or its own if it's talked to you.
		var owner: String = str(Data.neon["ships"].get(phrase, ["", ""])[1])
		if owner != "" and Career.contacts.has(owner):
			return [1, owner]
		return [1, phrase] if Career.contacts.has(phrase) else []
	match kind:
		"people":
			var who: String = links.get(phrase, phrase)
			return [1, who] if Career.contacts.has(who) else []
		"places":
			var key: String = links.get(phrase, "")
			if key != "":
				return [2, key]
			for id in Data.stations:
				var st: Dictionary = Data.stations[id]
				if phrase in [st["name"], st["nick"], str(st["nick"]).trim_prefix("the ")]:
					return [2, id]
			for id in Data.stations:
				if Data.systems.get(Data.stations[id]["system"], {}).get("name", "") == phrase:
					return [2, id]
		"charter", "navy", "dynasty", "tally", "karabey", "league":
			return [3, links[kind]]
	return []
