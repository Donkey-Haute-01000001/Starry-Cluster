extends Node2D
## Combat sandbox: your flagship and escorts against escalating pirate waves.

const ShipScript := preload("res://scripts/ship.gd")
const FxScript := preload("res://scripts/fx.gd")
const StarfieldScript := preload("res://scripts/starfield.gd")
const HudScript := preload("res://scripts/hud.gd")
const WheelScript := preload("res://scripts/tactics_wheel.gd")
const BodyScript := preload("res://scripts/body.gd")
const StationUIScript := preload("res://scripts/station_ui.gd")
const StoryScript := preload("res://scripts/story.gd")

const JUMP_CHARGE := 3.0

const COMBAT_RANGE := 1500.0
const CONTACT_RANGE := 2400.0   ## hostiles this close switch the autopilot off
const WHEEL_TIME_SCALE := 0.2

var world: Node2D
var fx: Node2D
var camera: Camera2D
var hud: Control
var pause_menu: Control
var sector_map: Control
var journal: Control
var launch_card: Control  ## the ID card on a new career's first launch
var wheel: Control

var player: Ship = null
var escorts: Array = []
var fleet_order := "engage"
var formation := "wedge"
var focus_target: Ship = null
var bait_ship: Ship = null     ## the escort drawing fire on a Bait order
var bait_t := 0.0
var fleet_heading := 0.0
var in_combat := false

var wave := 0
var next_wave_t := 3.0
var kills := 0
var message := ""
var message_t := 0.0

# Merchant mode: the Hesper March, one system loaded at a time.
var merchant := false
var system_id := ""
var bodies: Array = []
var station_ui: Control
var story: Node
var traffic: Traffic
var edge: Edge
var debt  ## Debt (scripts/debt.gd)
var docked_at := ""
var jump_charge := -1.0      ## seconds charged, or -1 when not charging
var jump_target: Node2D = null
var _pirate_t := 45.0
var _merchant_test := false
var hostile_count_before_jump := 0
var _first_fight := true
var _test_t := 0.0

var _wheel_mouse_world := Vector2.ZERO
var _shake := 0.0
var _was_burning := false
var _rumble: AudioStreamPlayer
var _zoom := 0.9

# Automated self-test: `godot --headless -- --autotest` runs a fight and prints stats.
var autotest := false
var _autotest_t := 0.0
var _losses := 0


func _ready() -> void:
	randomize()
	_setup_input()
	autotest = "--autotest" in OS.get_cmdline_user_args()

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var stars := Node2D.new()
	stars.set_script(StarfieldScript)
	stars.main = self
	bg_layer.add_child(stars)

	world = Node2D.new()
	world.name = "World"
	add_child(world)
	fx = Node2D.new()
	fx.set_script(FxScript)
	fx.z_index = 5
	world.add_child(fx)

	camera = Camera2D.new()
	camera.zoom = Vector2(_zoom, _zoom)
	world.add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Control.new()
	hud.set_script(HudScript)
	hud.main = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	wheel = Control.new()
	wheel.set_script(WheelScript)
	wheel.main = self
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.visible = false
	ui.add_child(wheel)
	pause_menu = Control.new()
	pause_menu.set_script(preload("res://scripts/pause_menu.gd"))
	pause_menu.main = self
	ui.add_child.call_deferred(pause_menu)
	sector_map = Control.new()
	sector_map.set_script(preload("res://scripts/sector_map.gd"))
	sector_map.main = self
	ui.add_child.call_deferred(sector_map)
	journal = Control.new()
	journal.set_script(preload("res://scripts/journal.gd"))
	journal.main = self
	ui.add_child.call_deferred(journal)

	merchant = Data.mode == "merchant"
	_merchant_test = "--merchant-test" in OS.get_cmdline_user_args()
	if _merchant_test:
		process_mode = Node.PROCESS_MODE_ALWAYS  # keep the scripted test running while docked
		Career.comms.connect(func(who, text): print("[comms] %s: %s" % [who, text]))
	if merchant:
		station_ui = Control.new()
		station_ui.set_script(StationUIScript)
		station_ui.main = self
		ui.add_child(station_ui)
		Career.comms.connect(hud.on_comms)
		Career.friend_joined.connect(spawn_friend)
		Career.friend_back.connect(spawn_friend)
		Career.crew_joined.connect(spawn_captain)
		Career.crew_left.connect(_captain_leaves)
		story = StoryScript.new()
		story.main = self
		add_child(story)
		traffic = Traffic.new(self)
		add_child(traffic)
		edge = Edge.new(self)
		world.add_child(edge)
		debt = preload("res://scripts/debt.gd").new(self)
		player = spawn_ship("light_freighter", 0, Vector2.ZERO)
		player.is_player = true
		player.controller = PlayerController.new(player, self)
		load_system(Career.system_id, "")
		if Career.friend_with_you():
			spawn_friend()
		for id in Career.crew:
			if Career.crew_with_you(id):
				spawn_captain(id)
		# The opening: you start docked at the Counter, where Charlie is waiting.
		# A continued run starts docked wherever you last saved.
		var at := "counter"
		if Career.resume_station != "" and Data.stations.has(Career.resume_station):
			at = Career.resume_station
		var st: Dictionary = Data.stations[at]
		player.position = st["pos"] + Vector2(0, 120)
		camera.global_position = player.position
		if Career.resume_station == "" and not _merchant_test:
			_launch()
			if "--new-career-test" in OS.get_cmdline_user_args():
				_new_career_test()
		else:
			dock(at)
		return

	player = spawn_ship("kestrel", 0, Vector2.ZERO)
	player.is_player = true
	if autotest:
		var ai := AIController.new(player, self)
		ai.freelance = true
		player.controller = ai
	else:
		player.controller = PlayerController.new(player, self)
	for i in 2:
		add_escort("wasp", Vector2(-80 - 40 * i, 70 * (1 if i % 2 else -1)))
	show_message("Pirates are inbound. Hold Tab to command your wingmen.", 5.0)


# --- Merchant mode: systems, docking and jumping ---------------------------

## Load a star system. `from_system` places the player at the matching jump point.
func load_system(id: String, from_system: String) -> void:
	clear_system()
	if from_system != "" and hostile_count_before_jump > 0:
		Career.friend_say("fled", true)
	hostile_count_before_jump = 0
	system_id = id
	Career.system_id = id
	var sys: Dictionary = Data.systems[id]
	for b in sys["bodies"]:
		_add_body(b["kind"], b)
	for sid in Data.stations:
		var st: Dictionary = Data.stations[sid]
		if st["system"] != id:
			continue
		var node := _add_body("station", {"pos": st["pos"]})
		node.id = sid
		node.set_station_art(st.get("art", ""), st.get("art_size", 220.0))
		node.label = st["nick"][0].to_upper() + st["nick"].substr(1)
		node.sublabel = st["name"]
	for j in sys["jumps"]:
		var node := _add_body("jump", {"pos": j["pos"]})
		node.id = j["to"]
		node.locked = j.get("locked", false)
		var dest_name: String = "the Crossroads" if j["to"] == "crossroads" else Data.systems[j["to"]]["name"]
		node.label = "Jump point: " + dest_name
		node.sublabel = "Writ of Passage required" if node.locked else "Hold position and press F to jump"
		if j["to"] == from_system and is_instance_valid(player):
			# Arrivals scatter a little around the rift.
			player.position = j["pos"] + (Vector2.ZERO - j["pos"]).normalized() * 380.0 + Vector2(randf_range(-80, 80), randf_range(-80, 80))
			player.velocity = (Vector2.ZERO - j["pos"]).normalized() * 60.0
			player.rotation = player.velocity.angle()
			camera.global_position = player.position
			# Escorts come through the rift with you.
			var k := 0
			for e in escorts:
				if is_instance_valid(e):
					k += 1
					e.position = player.position + Vector2(-90.0 * k, 60.0 * (1 if k % 2 else -1)).rotated(player.rotation)
					e.velocity = player.velocity
	_pirate_t = randf_range(60.0, 100.0)
	if traffic:
		traffic.on_load()
		edge.on_load()
		debt.on_load()
	Career.on_enter_system(id)
	show_message("%s  ·  %s  ·  %s" % [sys["name"], sys["nick"], sys["security"]], 4.0)
	if story:
		story.on_enter_system(id, from_system)


## Remove the current system's bodies, strangers and shots. Your fleet stays.
func clear_system() -> void:
	if traffic:
		traffic.clear()
	for b in bodies:
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()
	for s in get_tree().get_nodes_in_group("ships"):
		if s != player and not (s in escorts):
			s.remove_from_group("ships")
			s.queue_free()
	fx.projectiles.clear()


func _add_body(kind: String, data: Dictionary) -> Node2D:
	var n := Node2D.new()
	n.set_script(BodyScript)
	n.setup(kind, data)
	world.add_child(n)
	bodies.append(n)
	return n


## The nearest dockable station or jump point within reach of the player.
func nearby_interactable() -> Node2D:
	if not is_instance_valid(player):
		return null
	var best: Node2D = null
	var best_d := INF
	for b in bodies:
		if not is_instance_valid(b) or not (b.kind in ["station", "jump"]):
			continue
		var d: float = player.global_position.distance_to(b.global_position)
		if d < b.interact_range() and d < best_d:
			best = b
			best_d = d
	return best


func _try_interact() -> void:
	var w := traffic.wreck_near(player.global_position)
	if w:
		traffic.loot(w)
		return
	var b := nearby_interactable()
	if b == null:
		show_message("Nothing in range. Fly to a station or jump point.", 2.0)
		return
	if b.kind == "station":
		if player.velocity.length() > 140.0:
			show_message("Too fast to dock. Slow down (hold X to brake).", 2.0)
			return
		dock(b.id)
	elif b.kind == "jump":
		if b.locked:
			if Career.friend_with_you() and Career.friend["memory"] == "gate":
				Career.friend_say("callback", true)
			if Career.flags.get("papers", false):
				story.start_gate(b)
			else:
				show_message("Gate customs: no Writ of Passage, no jump. Pay off your Charter loan.", 3.5)
			return
		if jump_charge >= 0.0:
			return
		jump_charge = 0.0
		jump_target = b
		Sfx.play("jump_charge", -6.0)
		show_message("Charging jump drive...", 1.5)


func dock(id: String) -> void:
	docked_at = id
	jump_charge = -1.0
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		# Station crews patch you up while you're docked.
		player.hull_hp = player.max_hull
		player.shields = player.max_shields
		player.energy = player.max_energy
		player.restock()
	for e in escorts:
		if is_instance_valid(e):
			e.hull_hp = e.max_hull
			e.shields = e.max_shields
	Sfx.play("dock", -3.0)
	get_tree().paused = true
	station_ui.open(id)
	Career.on_dock(id)
	if not _merchant_test:
		Career.save_game(id)


## A new career: the rig eases out of the Counter's berth under your ID card,
## then Charlie calls with the first job.
func _launch() -> void:
	var st: Dictionary = Data.stations["counter"]
	player.position = st["pos"] + Vector2(0, float(st.get("art_size", 260.0)) * 0.5 + 60.0)
	player.rotation = PI * 0.5
	player.velocity = Vector2(0, 70)
	camera.global_position = player.position
	Sfx.play("undock", -3.0)
	var card := Control.new()
	card.set_script(preload("res://scripts/launch_card.gd"))
	hud.get_parent().add_child(card)
	launch_card = card
	card.finished.connect(func():
		launch_card = null
		Career.first_job())


func _new_career_test() -> void:
	await _wait(7.0)
	print("[launch] docked=%s card=%s jobs=%d log=%d waiting=%s objective=%s" % [docked_at, launch_card != null, Career.jobs.size(), Career.comms_log.size(), hud.comms_waiting(), Career.objective.get("text", "")])
	hud.advance_comms()
	hud.advance_comms()
	await _wait(1.0)
	print("[launch] after space: waiting=%s pilot=%s" % [hud.comms_waiting(), Career.pilot])
	sector_map.open()
	await _wait(0.3)
	print("[launch] map paused=%s" % get_tree().paused)
	journal.open()
	await _wait(0.3)
	print("[launch] journal over map: map=%s journal=%s paused=%s" % [sector_map.visible, journal.visible, get_tree().paused])
	journal.close()
	await _wait(0.3)
	print("[launch] closed: paused=%s" % get_tree().paused)
	get_tree().quit()


func undock() -> void:
	if docked_at == "":
		return
	docked_at = ""
	Sfx.play("undock", -3.0)
	station_ui.visible = false
	get_tree().paused = false


func _merchant_step(delta: float) -> void:
	if not is_instance_valid(player):
		return
	Career.advance(delta)
	# Jump charge: a few vulnerable seconds holding near the rift.
	if jump_charge >= 0.0:
		if not is_instance_valid(jump_target) or player.global_position.distance_to(jump_target.global_position) > jump_target.interact_range():
			jump_charge = -1.0
			show_message("Jump cancelled: you drifted out of the rift.", 2.0)
		else:
			jump_charge += delta
			if jump_charge >= JUMP_CHARGE:
				var from := system_id
				var dest: String = jump_target.id
				hostile_count_before_jump = hostile_count()
				jump_charge = -1.0
				_shake = 12.0
				Sfx.play("jump", -3.0)
				if dest == "crossroads":
					story.arrive_crossroads()
				else:
					load_system(dest, from)
	# An engineer friend patches the fleet up whenever nobody's shooting.
	if Career.friend_with_you() and Career.friend["role"] == "engineer" and hostile_count() == 0:
		for s in [player] + escorts:
			if is_instance_valid(s) and s.alive:
				s.hull_hp = minf(s.max_hull, s.hull_hp + s.max_hull * 0.02 * delta)
	traffic.step(delta)
	edge.step(delta)
	debt.step(delta)
	# Pirates hide in the rough systems' rocks. Mostly they hunt the lanes
	# (Traffic raids); now and then they come for you.
	var danger: float = Data.systems.get(system_id, Data.crossroads)["danger"]
	if danger > 0.0 and hostile_count() == 0 and not story.busy():
		_pirate_t -= delta
		if _pirate_t <= 0.0:
			_pirate_t = randf_range(150.0, 240.0) / danger
			var from_angle := randf() * TAU
			var c := player.global_position + Vector2.RIGHT.rotated(from_angle) * 1500.0
			for i in 2:
				var s := spawn_ship("raider", 1, c + Vector2(randf_range(-150, 150), randf_range(-150, 150)), from_angle + PI)
				s.controller = AIController.new(s, self)
			show_message("Pirate raiders inbound! Fight, or run for a station.", 3.5)
			if Career.friend_with_you() and Career.friend["memory"] in ["drip", "four"]:
				Career.friend_say("callback", true)


## Where the current objective points: a station here, or the jump toward it.
func objective_target() -> Node2D:
	if Career.objective.is_empty():
		return null
	var st_id: String = Career.objective["station"]
	var st_sys: String = Data.stations[st_id]["system"]
	var want_id := st_id
	var want_kind := "station"
	if st_sys != system_id:
		want_id = Career.next_hop(system_id, st_sys)
		want_kind = "jump"
	for b in bodies:
		if is_instance_valid(b) and b.kind == want_kind and b.id == want_id:
			return b
	return null


func _setup_input() -> void:
	var keys := {
		"thrust_forward": [KEY_W, KEY_UP], "thrust_back": [KEY_S, KEY_DOWN],
		"strafe_left": [KEY_A], "strafe_right": [KEY_D],
		"turn_left": [KEY_Q, KEY_LEFT], "turn_right": [KEY_E, KEY_RIGHT],
		"brake": [KEY_X], "fire_fixed": [KEY_SPACE], "tactics": [KEY_TAB], "target": [KEY_T],
		"restart": [KEY_R], "toggle_help": [KEY_H, KEY_F1], "interact": [KEY_F],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire_aimed"):
		InputMap.add_action("fire_aimed")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire_aimed", mb)
	if not InputMap.has_action("fire_secondary"):
		InputMap.add_action("fire_secondary")
	var rb := InputEventMouseButton.new()
	rb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("fire_secondary", rb)


# --- Spawning ------------------------------------------------------------

func spawn_ship(id: String, team: int, pos: Vector2, facing: float = 0.0) -> Ship:
	var s: Ship = ShipScript.new()
	s.setup(id, team, self)
	s.position = pos
	s.rotation = facing
	s.add_to_group("ships")
	s.destroyed.connect(_on_ship_destroyed)
	world.add_child(s)
	return s


func add_escort(id: String, offset: Vector2) -> Ship:
	var base := player.global_position if is_instance_valid(player) else Vector2.ZERO
	var s := spawn_ship(id, 0, base + offset)
	s.controller = AIController.new(s, self)
	escorts.append(s)
	_reassign_slots()
	return s


## The old friend joins as an escort, flying the ship their role came with.
func spawn_friend() -> void:
	if not is_instance_valid(player):
		return
	for e in escorts:
		if is_instance_valid(e) and e.is_friend:
			return
	var f: Dictionary = Career.friend
	var role: Dictionary = Data.friend_roles[f["role"]]
	var s := add_escort(role["hull"], Vector2(-120, 70).rotated(player.rotation))
	s.is_friend = true
	s.display_name = "%s (%s)" % [f["name"], role["ship"]]
	match f["role"]:
		"pilot":
			s.ace = true
		"gunner":
			s.accuracy = 0.35
			s.traverse_mult = 1.6
	match f["memory"]:
		"drip":
			s.shield_regen *= 1.4
		"four":
			s.max_hull *= 1.25
			s.hull_hp = s.max_hull


## A hired bar captain flies with you as an escort.
func spawn_captain(id: String) -> void:
	if not is_instance_valid(player):
		return
	for e in escorts:
		if is_instance_valid(e) and e.captain_id == id:
			return
	var c: Dictionary = Data.captains[id]
	var s := add_escort(c["hull"], Vector2(-150, -80).rotated(player.rotation))
	s.captain_id = id
	s.display_name = "%s (%s)" % [c["name"], c["ship"]]
	s.ace = c.get("ace", false)


func _captain_leaves(id: String) -> void:
	for e in escorts.duplicate():
		if is_instance_valid(e) and e.captain_id == id:
			escorts.erase(e)
			e.remove_from_group("ships")
			e.queue_free()
	_reassign_slots()


func spawn_wave() -> void:
	wave += 1
	var center := player.global_position if is_instance_valid(player) else Vector2.ZERO
	var from_angle := randf() * TAU
	var spawn_center := center + Vector2.RIGHT.rotated(from_angle) * 1700.0
	var raiders := 1 + wave
	var marauders := wave / 3
	for i in raiders:
		var p := spawn_center + Vector2(randf_range(-200, 200), randf_range(-200, 200))
		var s := spawn_ship("raider", 1, p, from_angle + PI)
		s.controller = AIController.new(s, self)
	for i in marauders:
		var p := spawn_center + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		var s := spawn_ship("marauder", 1, p, from_angle + PI)
		s.controller = AIController.new(s, self)
	show_message("Wave %d: %d pirate ships detected" % [wave, raiders + marauders], 3.0)


func spawn_projectile(pos: Vector2, angle: float, w: Dictionary, shooter: Ship, fuse := -1.0) -> void:
	fx.spawn_projectile(pos, angle, w, shooter, fuse)


func spawn_sparks(pos: Vector2, color: Color, count: int) -> void:
	fx.spawn_sparks(pos, color, count)


func spawn_explosion(pos: Vector2, radius: float, vel: Vector2) -> void:
	fx.spawn_explosion(pos, radius, vel)
	if is_instance_valid(player):
		var d := pos.distance_to(player.global_position)
		_shake = maxf(_shake, clampf(radius * 0.6 * (1.0 - d / 1500.0), 0.0, 22.0))


func _on_ship_destroyed(s: Ship) -> void:
	if s.team == 2:
		if traffic:
			traffic.on_ship_destroyed(s)
		return
	if s == player:
		player = null
		jump_charge = -1.0
		show_message("", 0.0)
		return
	if s.team == 1:
		kills += 1
		if merchant:
			Career.friend_say("first_kill", true)
	elif s.team == 3:
		Career.obstruct()
		Career.obstruct()
		return
	else:
		if s.is_friend:
			Career.friend_shot_down()
		_losses += 1
		show_message("%s lost!" % s.def["name"], 2.0)
	escorts.erase(s)
	_reassign_slots()
	if s == focus_target:
		focus_target = null


func _reassign_slots() -> void:
	var i := 0
	for e in escorts:
		if is_instance_valid(e):
			e.controller.slot_index = i
			i += 1


# --- Queries used by AI and HUD -------------------------------------------

func hostile_count() -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("ships"):
		if s.alive and s.team == 1:
			n += 1
	return n


## Raiders (team 1) are everyone's enemy; you (0) and the March's own
## traffic (2) leave each other alone.
func hostile(a: int, b: int) -> bool:
	# 1 = raiders, against everyone. 3 = Charter Recovery, after you and your wing only.
	return a != b and (a == 1 or b == 1 or (a == 3 and b == 0) or (a == 0 and b == 3))


## The ship under the mouse cursor, if any (not yours).
func ship_under_mouse() -> Ship:
	var m := mouse_world()
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship and ship.alive and ship != player and m.distance_to(ship.global_position) < ship.radius + 26.0:
			return ship
	return null


## Nearest live enemy of `team` to `from`, limited to `max_dist` from `center` (default: from).
func nearest_enemy(team: int, from: Vector2, max_dist: float, center = null) -> Ship:
	var c: Vector2 = from if center == null else center
	var best: Ship = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == null or not ship.alive or not hostile(team, ship.team) or ship.disabled:
			continue
		if c.distance_to(ship.global_position) > max_dist:
			continue
		var d := from.distance_squared_to(ship.global_position)
		if d < best_d:
			best_d = d
			best = ship
	return best


func formation_slot(i: int) -> Vector2:
	var n := maxi(escorts.size(), 1)
	var offset := Vector2.ZERO
	var side := -1.0 if i % 2 == 0 else 1.0
	var row := i / 2 + 1
	match formation:
		"wedge":
			offset = Vector2(-75.0 * row, 75.0 * row * side)
		"line":
			offset = Vector2(-15.0, 85.0 * row * side)
		"ring":
			offset = Vector2.RIGHT.rotated(TAU * float(i) / n + PI / n) * 150.0
	# Screening and breaking off pull the wing in tight around you.
	if fleet_order in ["screen", "break"]:
		offset *= 0.7
	var base := player.global_position if is_instance_valid(player) else Vector2.ZERO
	return base + offset.rotated(fleet_heading)


func mouse_world() -> Vector2:
	return world.get_global_mouse_position()


func wheel_open() -> bool:
	return wheel.visible


func show_message(text: String, duration: float) -> void:
	message = text
	message_t = duration


func apply_tactic(id: String) -> void:
	match id:
		"wedge", "line", "ring":
			formation = id
			show_message("Formation: %s" % id.capitalize(), 1.5)
		"engage":
			fleet_order = "engage"
			show_message("Wingmen: engage at will", 1.5)
		"hold":
			fleet_order = "hold"
			show_message("Wingmen: hold formation", 1.5)
		"screen":
			fleet_order = "screen"
			show_message("Wingmen: screen me", 1.5)
		"break":
			fleet_order = "break"
			show_message("Wingmen: break off, form on me", 1.5)
		"bait":
			_order_bait()
		"focus":
			_order_focus(_wheel_mouse_world)


## One wingman, the fastest steady hand, runs at the enemy and drags them off.
## The rest fall on whatever turns to chase.
func _order_bait() -> void:
	var best: Ship = null
	var best_score := -INF
	for e in escorts:
		if not is_instance_valid(e) or not e.alive:
			continue
		var score: float = e.max_speed + (0.0 if e.controller.temper() == "hesitant" else 1000.0) + 300.0 * e.hull_hp / e.max_hull
		if score > best_score:
			best_score = score
			best = e
	if best == null:
		show_message("No wingmen to send", 1.5)
		return
	if nearest_enemy(0, player.global_position, COMBAT_RANGE) == null:
		show_message("Nothing to bait", 1.5)
		return
	bait_ship = best
	bait_t = 14.0
	best.controller.start_bait()
	fleet_order = "bait"
	var nm: String = best.display_name.get_slice(" (", 0) if best.display_name != "" else str(best.def["name"])
	show_message("%s: baiting" % nm, 1.5)


## The nearest hostile coming for you: inside `within`, or anything locked on you a bit further out.
func threat_to_player(within := 700.0) -> Ship:
	if not is_instance_valid(player):
		return null
	var best: Ship = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == null or not ship.alive or not hostile(0, ship.team):
			continue
		var d := ship.global_position.distance_to(player.global_position)
		var locked: bool = ship.controller is AIController and ship.controller.target == player
		if d < within or (locked and d < within * 1.8):
			if d < best_d:
				best_d = d
				best = ship
	return best


func _order_focus(at: Vector2) -> void:
	var t := nearest_enemy(0, at, 600.0)
	if t == null:
		show_message("No target near the cursor", 1.5)
		return
	focus_target = t
	fleet_order = "focus"
	show_message("Wingmen: attack %s" % t.def["name"], 1.5)


# --- Loop ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
		if pause_menu and pause_menu.can_open():
			pause_menu.open()
			get_viewport().set_input_as_handled()
		return
	# Comms wait for you: Space, Enter, or a click on the panel moves them on.
	if hud.comms_showing() and ((event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hud.comms_rect.has_point(event.position))):
		hud.advance_comms()
		get_viewport().set_input_as_handled()
		return
	if launch_card and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		launch_card.skip()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart") and not is_instance_valid(player):
		Engine.time_scale = 1.0
		if merchant:
			get_tree().change_scene_to_file("res://scenes/start.tscn")
		else:
			get_tree().reload_current_scene()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and is_instance_valid(player):
		var nm: String = player.cycle_secondary()
		if nm != "":
			show_message("Secondary: %s" % nm, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		PlayerController.toggle("assist")
		show_message("Flight assist %s" % ("ON: drift damped" if PlayerController.assist else "OFF: pure drift"), 2.0)
	elif not merchant and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		PlayerController.toggle("mouse_steer")
		show_message("Mouse steering %s" % ("ON: ship faces the cursor" if PlayerController.mouse_steer else "OFF: Q/E to turn"), 2.0)
	elif merchant and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y and is_instance_valid(player):
		var hs := ship_under_mouse()
		if hs and hs.team != 0 and hs.global_position.distance_to(player.global_position) < 3000.0:
			traffic.hail(hs)
		else:
			show_message("Hover a ship to hail it.", 1.5)
	elif merchant and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G and is_instance_valid(player):
		toggle_autopilot()
	elif merchant and event.is_action_pressed("interact") and is_instance_valid(player):
		_try_interact()
	elif event.is_action_pressed("toggle_help"):
		hud.show_help = not hud.show_help
	elif event.is_action_pressed("target"):
		_order_focus(mouse_world())
	elif event.is_action_pressed("tactics"):
		_wheel_mouse_world = mouse_world()
		wheel.visible = true
		Engine.time_scale = WHEEL_TIME_SCALE
	elif event.is_action_released("tactics") and wheel.visible:
		var id: String = wheel.current_id()
		wheel.visible = false
		Engine.time_scale = 1.0
		if id != "":
			apply_tactic(id)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.1, 0.4, 1.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.1, 0.4, 1.4)


func _physics_process(delta: float) -> void:
	if is_instance_valid(player):
		if player.velocity.length() > 60.0:
			fleet_heading = lerp_angle(fleet_heading, player.velocity.angle(), 2.5 * delta)
		# A called ceasefire ends the fight, even with their guns still in sight.
		in_combat = nearest_enemy(0, player.global_position, COMBAT_RANGE) != null and not (story and story.ceasefire())
	else:
		in_combat = false

	if focus_target != null and (not is_instance_valid(focus_target) or not focus_target.alive):
		focus_target = null
	if fleet_order == "focus" and focus_target == null:
		fleet_order = "engage"
	if fleet_order == "bait":
		bait_t -= delta
		var done := bait_t <= 0.0 or not is_instance_valid(bait_ship) or not bait_ship.alive \
			or bait_ship.hull_hp < bait_ship.max_hull * 0.35 or nearest_enemy(0, bait_ship.global_position, 2600.0) == null
		if done:
			if is_instance_valid(bait_ship) and bait_ship.alive:
				show_message("%s is back on your wing" % bait_ship.display_name.get_slice(" (", 0), 1.5)
			bait_ship = null
			fleet_order = "engage"
	elif bait_ship != null:
		bait_ship = null

	if merchant:
		_travel_step()
		_merchant_step(delta)
		if _merchant_test:
			_merchant_test_step(delta)
	elif hostile_count() == 0:
		if next_wave_t <= 0.0:
			next_wave_t = 6.0 if wave > 0 else 2.0
			if wave > 0:
				_between_waves()
		next_wave_t -= delta
		if next_wave_t <= 0.0:
			spawn_wave()
			next_wave_t = 0.0
	message_t = maxf(0.0, message_t - delta)
	_separate_ships(delta)

	if autotest:
		_autotest_step(delta)


# --- Autopilot and fast travel ----------------------------------------------------

func autopilot_on() -> bool:
	return is_instance_valid(player) and player.controller is PlayerController and player.controller.autopilot != null


func toggle_autopilot() -> void:
	var pc := player.controller as PlayerController
	if pc == null:
		return
	if pc.autopilot != null:
		pc.autopilot = null
		autopilot_off("Autopilot off.")
		return
	var t := objective_target()
	if t == null:
		show_message("No job plotted. Take one at a station board.", 2.0)
		return
	if story.busy() or story.boarding != null:
		return
	pc.autopilot = t
	Career.flags["used_autopilot"] = true
	show_message("Autopilot: %s.  Any flight key takes over" % t.label, 2.5)


func autopilot_off(why: String) -> void:
	if is_instance_valid(player) and player.controller is PlayerController:
		player.controller.autopilot = null
	if why != "":
		show_message(why, 2.0)


## Runs every physics frame in merchant mode: autopilot arrival.
func _travel_step() -> void:
	if not is_instance_valid(player):
		return
	var contact := nearest_enemy(0, player.global_position, CONTACT_RANGE) != null
	if autopilot_on():
		var t: Node2D = player.controller.autopilot
		var d := player.global_position.distance_to(t.global_position)
		if contact or story.busy():
			autopilot_off("Contact! Autopilot off." if contact else "")
		elif d < t.interact_range() * 0.6 and player.velocity.length() < 60.0:
			player.controller.autopilot = null
			if t.kind == "station":
				dock(t.id)
			else:
				show_message("At the jump point.  [F] to jump", 2.5)


## Soft collisions: ships that overlap gently push apart instead of stacking.
func _separate_ships(delta: float) -> void:
	var ships := get_tree().get_nodes_in_group("ships")
	for i in ships.size():
		var a := ships[i] as Ship
		if a == null or not a.alive:
			continue
		for j in range(i + 1, ships.size()):
			var b := ships[j] as Ship
			if b == null or not b.alive:
				continue
			var d := b.global_position - a.global_position
			var min_d := (a.radius + b.radius) * 1.15
			var dist := d.length()
			if dist >= min_d or dist < 0.001:
				continue
			var push := d / dist * (min_d - dist) * 6.0 * delta
			var wa := b.radius / (a.radius + b.radius)
			a.position -= push * wa
			b.position += push * (1.0 - wa)
			a.velocity -= push * wa * 4.0
			b.velocity += push * (1.0 - wa) * 4.0


func _between_waves() -> void:
	# Sandbox convenience: top the fleet back up between waves.
	if is_instance_valid(player):
		player.hull_hp = minf(player.max_hull, player.hull_hp + player.max_hull * 0.35)
	var alive := 0
	for e in escorts:
		if is_instance_valid(e):
			alive += 1
	if alive < 2 and is_instance_valid(player):
		add_escort("wasp", Vector2(-300, 0).rotated(fleet_heading))
		show_message("Wave cleared. A replacement wingman has joined you.", 3.0)
	else:
		show_message("Wave cleared!", 2.5)


func _process(delta: float) -> void:
	if is_instance_valid(player):
		var look := (mouse_world() - player.global_position).limit_length(1200.0) * 0.08
		if autotest:
			look = Vector2.ZERO
		var target := player.global_position + look + player.velocity * 0.15
		camera.global_position = camera.global_position.lerp(target, clampf(8.0 * delta, 0.0, 1.0))
	var want := _zoom
	if is_instance_valid(player):
		# Pull back a little as you pick up speed.
		var sk := clampf(player.velocity.length() / maxf(player.max_speed, 1.0), 0.0, 1.0)
		want *= 1.0 - 0.06 * sk
		# Kick when you take a hit.
		if player.since_hit < delta and player.alive:
			_shake = maxf(_shake, 5.0)
		_engine_sound(delta)
	var z := lerpf(camera.zoom.x, want, clampf(6.0 * delta, 0.0, 1.0))
	camera.zoom = Vector2(z, z)
	_shake = maxf(0.0, _shake - 40.0 * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


## Engine rumble: a low loop that swells and rises with the main engine.
func _engine_sound(delta: float) -> void:
	if _rumble == null:
		_rumble = Sfx.loop("engine", -40.0)
		if _rumble.stream == null:
			return
		_rumble.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(_rumble)
	if _rumble.stream == null:
		return
	var k := clampf(absf(player.thrust_out.x) + absf(player.thrust_out.y) * 0.4, 0.0, 1.0)
	if not player.alive or docked_at != "" or player.ion_t > 0.0:
		k = 0.0
	var spd := clampf(player.velocity.length() / 600.0, 0.0, 1.0)
	var want_db := lerpf(-38.0, -17.0, k)
	_rumble.volume_db = lerpf(_rumble.volume_db, want_db, clampf(6.0 * delta, 0.0, 1.0))
	_rumble.pitch_scale = lerpf(_rumble.pitch_scale, 0.75 + 0.35 * k + 0.2 * spd, clampf(4.0 * delta, 0.0, 1.0))


func _autotest_step(delta: float) -> void:
	_autotest_t += delta
	var frame := int(_autotest_t * 60.0)
	# Exercise every order and formation so the AI paths all get run.
	if frame % 1200 == 600:
		var orders := ["bait", "screen", "break", "focus", "engage", "hold"]
		var forms := ["wedge", "line", "ring"]
		var k := (frame / 1200) % orders.size()
		formation = forms[k % 3]
		if orders[k] == "focus":
			_order_focus(player.global_position if is_instance_valid(player) else Vector2.ZERO)
		elif orders[k] == "bait":
			_order_bait()
		else:
			fleet_order = orders[k]
	var shots_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if shots_dir != "":
		if frame == 60 * 14:
			wheel.visible = true
		if frame in [60 * 4, 60 * 9, 60 * 14 + 2, 60 * 22, 60 * 33]:
			get_viewport().get_texture().get_image().save_png("%s/shot_%03d.png" % [shots_dir, frame / 60])
		if frame == 60 * 14 + 4:
			wheel.visible = false
	if frame % 600 == 0:
		var hp := "dead"
		if is_instance_valid(player):
			hp = "%d/%d e=%d" % [int(player.shields), int(player.hull_hp), int(player.energy)]
		print("[autotest] t=%.0fs wave=%d kills=%d escort_losses=%d hostiles=%d escorts=%d player=%s projectiles=%d" % [
			_autotest_t, wave, kills, _losses, hostile_count(), escorts.size(), hp, fx.projectiles.size()])
		var st := []
		for e in escorts:
			if is_instance_valid(e) and e.controller is AIController:
				st.append("%s%s" % [e.controller.obeyed, "*" if e == bait_ship else ""])
		print("[autotest] order=%s escorts=%s" % [fleet_order, st])
	if _autotest_t >= 120.0 or not is_instance_valid(player):
		print("[autotest] done: wave=%d kills=%d escort_losses=%d player_alive=%s" % [wave, kills, _losses, is_instance_valid(player)])
		get_tree().quit()


## Automated check of the Merchant opening: `-- --merchant-test`. Plays the
## whole opening by teleporting between stops and prints the state as it goes.
## Add `--shots=DIR` to save screenshots along the way.
func _merchant_test_step(_delta: float) -> void:
	if _test_t == 0.0:
		_test_t = 1.0
		_run_merchant_test()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func _shot(name: String) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [a.substr(8), name])


func _go(station: String) -> void:
	player.position = Data.stations[station]["pos"] + Vector2(100, 0)
	player.velocity = Vector2.ZERO
	dock(station)


func _run_merchant_test() -> void:
	# --look=a,b,...: quick screenshots only (station ids, "rift", "crossroads").
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look="):
			await _wait(0.3)
			for what in a.substr(7).split(","):
				if what == "crossroads":
					if station_ui.visible:
						undock()
					spawn_captain("fay")
					spawn_captain("mersham")
					await _wait(0.5)
					story.scene = "ending"
					story.arrive_crossroads()
					await _wait(9.0)
				elif what in ["map", "maphover", "launch", "comms"] or what.begins_with("journal") or what.begins_with("mapnote"):
					# The paperwork overlays, with a little history to show.
					if Career.pilot.get("name", "") in ["", "Unnamed"]:
						Career.pilot = {"name": "Hollis Graye", "rig": "Long Haul", "photo": 8}
					if station_ui.visible:
						undock()
					await _wait(0.5)
					if what.begins_with("map") or what.begins_with("journal"):
						# Some history to fill the pages.
						Career.flags["tally_hailed"] = true
						Career.flags["tally_done"] = true
						Career.flags["franz_met"] = true
						Career.flags["bounty_taken"] = true
						Career.visited["marcellus"] = true
						Career.friend["met"] = true
						Career.say("Franz", Data.franz["intro"])
						Career.say("Tallyman", Data.tally["signoff"])
						journal._tab = int(what.substr(7)) if what.length() > 7 else 0
						journal._sel[1] = 1
						if what.begins_with("map"):
							sector_map.open()
							if what == "maphover":
								sector_map._hover = "region_2"
							elif what.begins_with("mapnote"):
								sector_map._note_hover = int(what.substr(7))
						else:
							journal.open()
						await get_tree().create_timer(2.4).timeout
					elif what == "launch":
						_launch()
						await _wait(1.6)
					elif what == "comms":
						hud._comms_queue.append(["Charlie", "Second line waiting."])
						hud._show_comms("Charlie", Data.charlie["first_job"])
						hud._comms_hold = true
						await _wait(3.0)
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					_shot("look_" + what)
					if what.begins_with("map"):
						sector_map.close()
					elif what.begins_with("journal"):
						journal.close()
					continue
				elif what == "fay":
					Career.credits += 5000
					Career.hire("fay")
					if station_ui.visible:
						undock()
					await _wait(1.5)
					for e in escorts:
						if is_instance_valid(e):
							camera.zoom = Vector2(2.2, 2.2)
							camera.global_position = e.global_position
							player.position = e.global_position + Vector2(-60, 40)
					await _wait(0.2)
				elif what.begins_with("sys_"):
					# Fly-by of one system's backdrop, away from stations.
					if station_ui.visible:
						undock()
					Career.flags["tally_done"] = true
					load_system(what.substr(4), "")
					player.global_position = Vector2(1200, 900)
					player.velocity = Vector2(200, 0)
					await _wait(1.5)
				elif what == "turret":
					# The freighter's flak turret on a raider, aimed by hand.
					if station_ui.visible:
						undock()
					Career.flags["tally_done"] = true
					load_system("marcellus", "")
					player.global_position = Vector2(1500, 900)
					player.velocity = Vector2.ZERO
					var pc = player.controller
					player.controller = null
					var foe: Ship = spawn_ship("raider", 1, player.global_position + Vector2(380, -160), PI)
					foe.controller = null
					foe.hold_fire = true
					for k in 50:
						player.aim_point = foe.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
						player.in_fire_aimed = true
						await _wait(0.02)
					player.in_fire_aimed = false
					print("[turret] foe hull=%d/%d shields=%d" % [int(foe.hull_hp), int(foe.max_hull), int(foe.shields)])
					_shot("look_turret_flak")
					# Ion bolt, then a torpedo.
					player.in_turn = 0.0
					player.rotation = (foe.global_position - player.global_position).angle()
					player.aim_point = foe.global_position
					player.in_fire_secondary = true
					await _wait(0.1)
					player.in_fire_secondary = false
					await _wait(0.6)
					print("[secondary] after ion: foe ion_t=%.1f shields=%d" % [foe.ion_t, int(foe.shields)])
					player.cycle_secondary()
					player.in_fire_secondary = true
					await _wait(0.1)
					player.in_fire_secondary = false
					await _wait(0.35)
					_shot("look_torpedo")
					await _wait(0.8)
					print("[secondary] after torpedo: foe alive=%s hull=%d ammo=%d" % [is_instance_valid(foe) and foe.alive, int(foe.hull_hp) if is_instance_valid(foe) else 0, player.secondaries[1]["ammo"]])
					player.controller = pc
				elif what == "assist":
					# Drift check: sideways and forward drift, no input.
					if station_ui.visible:
						undock()
					player.global_position = Vector2(1200, 900)
					player.rotation = 0.0
					player.velocity = Vector2(200, 200)
					for i in 4:
						await _wait(0.5)
						var lv: Vector2 = player.velocity.rotated(-player.rotation)
						print("[assist] t=%.1f forward=%d side=%d" % [0.5 + i * 0.5, int(lv.x), int(lv.y)])
				elif what == "hail":
					# The Tallyman's reply card over his longest line.
					if station_ui.visible:
						undock()
					Career.say("Tallyman", Data.tally["hail"])
					story._show_choices()
					await _wait(4.0)
					_shot("look_hail_card")
					story.choose(0)
				elif what == "autopilot":
					# From Aurelia's edge to the job's station on autopilot, then a tip shot.
					if station_ui.visible:
						undock()
					Career.flags["tally_done"] = true
					Career.flags["tip_fly"] = true
					load_system("aurelia", "")
					player.global_position = Vector2(2600, -1800)
					player.velocity = Vector2.ZERO
					await _wait(1.5)
					_shot("look_tip_travel")
					var t := objective_target()
					print("[auto] target=%s dist=%d" % [t.label if t else "none", int(player.global_position.distance_to(t.global_position)) if t else -1])
					toggle_autopilot()
					var el := 0.0
					while docked_at == "" and el < 60.0:
						await _wait(1.0)
						el += 1.0
						if int(el) % 5 == 0:
							print("[auto] t=%d dist=%d speed=%d on=%s" % [el, int(player.global_position.distance_to(t.global_position)), int(player.velocity.length()), autopilot_on()])
						if int(el) == 6:
							_shot("look_autopilot")
					print("[auto] docked=%s at=%s after %ds" % [docked_at != "", docked_at, el])
				elif what in ["traffic", "lanes", "wall"]:
					# The March at work: a busy lane in Aurelia, the queue at the Wall.
					if station_ui.visible:
						undock()
					Career.flags["tally_done"] = true
					var sys_id := "aurelia" if what != "wall" else "porta_aquila"
					load_system(sys_id, "")
					var at: Vector2 = Vector2(2000, -1100) if what == "traffic" else (Vector2(1800, -1300) if what == "lanes" else Vector2(1500, 0))
					player.global_position = at
					player.velocity = Vector2.ZERO
					camera.global_position = at
					await _wait(3.0)
					print("[traffic] %s ships=%d" % [sys_id, traffic.ships().size()])
					for s2 in traffic.ships():
						print("[traffic]   %s  %s  %s  %s" % [s2.display_name, s2.info.get("owner", ""), s2.info.get("job", ""), s2.global_position.round()])
					if what == "traffic":
						# Hover the nearest ship to show its tag.
						var hv: Ship = null
						for s3 in traffic.ships():
							if hv == null or s3.global_position.distance_to(camera.global_position) < hv.global_position.distance_to(camera.global_position):
								hv = s3
						if hv:
							hv.controller = null
							hv.velocity = Vector2.ZERO
							hv.in_move = Vector2.ZERO
							camera.global_position = hv.global_position + Vector2(-250, 120)
							player.global_position = camera.global_position + Vector2(-100, 100)
							await _wait(0.3)
							get_viewport().warp_mouse(get_viewport().get_visible_rect().size * 0.5 + (hv.global_position - camera.global_position) * camera.zoom)
							await _wait(0.3)
					_shot("look_" + what)
				elif what == "raid":
					if station_ui.visible:
						undock()
					Career.flags["tally_done"] = true
					Career.flags["tally_hailed"] = true
					load_system("marcellus", "aurelia")
					await _wait(1.0)
					traffic._incident_t = 0.0
					await _wait(0.3)
					var v = traffic.incident.get("victim")
					print("[raid] kind=%s victim=%s" % [traffic.incident.get("kind", "none"), v.display_name if v else "-"])
					if v:
						player.global_position = v.global_position + Vector2(-700, 300)
						camera.global_position = player.global_position
						player.velocity = Vector2.ZERO
					await _wait(2.5)
					if is_instance_valid(v):
						player.global_position = v.global_position + Vector2(-450, 260)
						camera.global_position = v.global_position + Vector2(-200, 100)
						get_viewport().warp_mouse(get_viewport().get_visible_rect().size * 0.5 + (v.global_position - camera.global_position) * camera.zoom)
					await _wait(0.2)
					_shot("look_raid")
					for i in 40:
						await _wait(1.0)
						if traffic.incident.is_empty():
							break
					print("[raid] over after %ds; wrecks=%s; credits=%d" % [int(traffic.incident.get("t", 0.0)), traffic._wrecks, Career.credits])
				elif what == "ahead":
					if station_ui.visible:
						undock()
					Career.first_job()
					Career.jobs[0]["loaded"] = true
					Career.job_cargo["water"] = 20
					load_system("tiberine", "aurelia")
					var shot := 0
					for i in 70:
						await _wait(1.0)
						if is_instance_valid(story._rig) and is_instance_valid(player):
							# Fly along behind it, the way a player on the run would.
							player.global_position = player.global_position.move_toward(story._rig.global_position + Vector2(-900, 300), 200.0)
							player.velocity = Vector2.ZERO
							camera.global_position = player.global_position.lerp(story._rig.global_position, 0.5)
						if i % 10 == 0 or (story._phase == "strip" and shot == 0):
							print("[ahead] t=%d phase=%s rig=%s raiders=%d" % [i, story._phase, (story._rig.display_name + (" disabled" if story._rig.disabled else "")) if is_instance_valid(story._rig) else "-", story._raiders.size()])
						if story._phase == "raid" and shot == 0 and i > 2:
							shot = 1
							_shot("look_ahead_raid")
						if story._phase == "strip" and shot == 1:
							shot = 2
							_shot("look_ahead_strip")
						if story.scene == "":
							break
					print("[ahead] done flags robbed=%s done=%s" % [Career.flags.get("ahead_robbed"), Career.flags.get("ahead_done")])
					_go("greenhouse")
					await _wait(0.5)
					print("[ahead] objective=%s" % Career.objective)
				elif what == "neon":
					if station_ui.visible:
						undock()
					load_system("marcellus", "")
					await _wait(1.0)
					Career.say("Charlie", "Franz Kessler says the Navy can't spare a cutter for Four this week. You're two days overdue, and Charter Recovery has your file. [shake]Pay the 2,500 cr[/shake] or they send the repo cutter.")
					Career.say("Dez", "Saltgate's got a bar. The Dynasty boys drink there.", true)
					await _wait(1.6)
					_shot("look_neon_typing")
					await _wait(4.0)
					_shot("look_neon")
				elif what == "scenic":
					if station_ui.visible:
						undock()
					load_system("tiberine", "")
					await _wait(0.3)
					for c in ["fay", "mersham"]:
						spawn_captain(c)
					Career.friend["met"] = true
					spawn_friend()
					var w := add_escort("navy_wing", Vector2(-200, 120))
					w.display_name = "Mbeki"
					formation = "wedge"
					player.controller = null
					player.global_position = Vector2(-820, 760)
					player.rotation = -0.45
					player.velocity = Vector2.RIGHT.rotated(-0.45) * 150.0
					fleet_heading = -0.45
					for e in escorts:
						if is_instance_valid(e):
							e.global_position = formation_slot(escorts.find(e))
							e.velocity = player.velocity
							e.rotation = -0.45
					hud.visible = false
					_zoom = 1.05
					for i in 14:
						player.velocity = Vector2.RIGHT.rotated(-0.45) * 110.0
						player.in_move = Vector2.ZERO
						await _wait(0.5)
					Music._credit_t = -1.0
					Music._credit.queue_redraw()
					await _wait(0.2)
					_shot("look_scenic")
				elif what == "forks":
					if station_ui.visible:
						undock()
					# Lanes: a scavenger's prices and hails.
					var b0 := Career.buy_price("bones", "parts")
					Career.flags["rigs_looted"] = 3
					print("[forks] rep=%d buy %d -> %d" % [Career.lane_rep(), b0, Career.buy_price("bones", "parts")])
					Career.flags["rigs_looted"] = 0
					Career.flags["rigs_saved"] = 2
					Career.remember("saved_names", "Tin Saint")
					# The Tallyman's job.
					Career.flags["tally_job"] = true
					Career.flags["tally_done"] = true
					Career.flags["tally_hailed"] = true
					load_system("marcellus", "aurelia")
					await _wait(1.0)
					var h: Ship = story._hauler
					print("[forks] hauler=%s team=%d" % [h.display_name if h else "-", h.team if h else -1])
					if h:
						player.global_position = h.global_position + Vector2(-500, 0)
						h.take_damage(99999.0, h.global_position)
					await _wait(9.0)
					print("[forks] side=%s crew=%s loan=%d" % [Career.flags.get("side"), Career.crew.keys(), Career.loan_balance])
					# The paymaster's knife.
					Career.flags["bounty_paid"] = true
					Career.flags["shady_done"] = 2
					story._hunt_t = 0.5
					await _wait(2.0)
					print("[forks] hunter=%s angry=%s offer=%s" % [story._hunter.display_name if is_instance_valid(story._hunter) else "-", Career.paymaster_angry(), Career.shady_offer("bones").is_empty()])
					Career.flags["busted"] = 1
					print("[forks] gate lines=%s" % [story._crossroads_lines().map(func(l): return l[1])])
				elif what == "repo":
					if station_ui.visible:
						undock()
					Career.strikes = 2
					Career.arrears = 1200
					Career.cargo["water"] = 10
					load_system("aurelia", "")
					player.global_position = Vector2(-600, 900)
					camera.global_position = player.global_position
					debt._hunt_t = 0.3
					await _wait(4.0)
					print("[repo] cutter=%s dist=%d" % [is_instance_valid(debt.cutter), debt.cutter.global_position.distance_to(player.global_position) if is_instance_valid(debt.cutter) else -1])
					_shot("look_repo")
					for i in 40:
						await _wait(1.0)
						if not debt.slip.is_empty():
							break
					print("[repo] slip=%s loan=%d credits=%d strikes=%d" % [debt.slip, Career.loan_balance, Career.credits, Career.strikes])
					await _wait(1.6)
					_shot("look_repo_slip")
					await _wait(4.0)
					print("[repo] docked=%s" % docked_at)
				elif what == "shady":
					Career.flags["starter_done"] = true
					var offer := Career.shady_offer("bones")
					print("[shady] offer=%s" % offer)
					load_system("aurelia", "")
					_go("bones")
					await _wait(1.0)
					_shot("look_shady_note")
					Career.take_shady(offer)
					if station_ui.visible:
						undock()
					var navy := spawn_ship("navy_patrol", 2, player.global_position + Vector2(400, 0))
					navy.add_to_group("traffic")
					navy.info = {"group": "navy", "owner": "Federation Navy", "job": "patrol"}
					await _wait(2.0)
					_shot("look_scan")
					await _wait(3.0)
					print("[shady] sealed=%s busted=%s credits=%d" % [Career.job_cargo.get("sealed", 0), Career.flags.get("busted", 0), Career.credits])
				elif what == "orders":
					if station_ui.visible:
						undock()
					spawn_captain("fay")
					spawn_captain("mersham")
					spawn_friend()
					var foe: Ship = null
					for k in 3:
						foe = spawn_ship("raider", 1, player.global_position + Vector2(1500, -200 + 150 * k))
						foe.controller = AIController.new(foe, self)
					await _wait(1.5)
					_wheel_mouse_world = foe.global_position
					wheel.visible = true
					get_viewport().warp_mouse(get_viewport().get_visible_rect().size * 0.5 + Vector2(40, 150))
					await _wait(0.4)
					_shot("look_wheel")
					wheel.visible = false
					apply_tactic("bait")
					for k in 2:
						await _wait(0.6 if k == 0 else 3.0)
						var st := []
						for e in escorts:
							st.append("%s=%s" % [e.display_name.get_slice(" (", 0), hud._escort_state(e)[0]])
						print("[orders] %s %s" % [fleet_order, st])
						_shot("look_orders%d" % k)
				elif what == "tow":
					if station_ui.visible:
						undock()
					load_system("tiberine", "aurelia")
					player.global_position = Vector2(edge.radius + 300.0, 0)
					camera.global_position = player.global_position
					edge.reserve = 0.03
					player.rotation = 0.0
					Input.action_press("thrust_forward")
					await _wait(2.0)
					_shot("look_reserve")
					Input.action_release("thrust_forward")
					await _wait(7.5)
					print("[tow] slip=%s loan=%d" % [edge.slip, Career.loan_balance])
					_shot("look_tow")
					await _wait(4.0)
					print("[tow] docked=%s tows=%s" % [docked_at, Career.flags.get("tows")])
				elif what == "board":
					if station_ui.visible:
						undock()
					Career.flags["franz_met"] = true
					Career.take_bounty()
					Career.flags["tally_done"] = true
					load_system("marcellus", "aurelia")
					player.position = Data.stations["ambers"]["pos"] + Vector2(300, 0)
					await _wait(1.0)
					var lark: Ship = story._bounty_ship
					for sh in get_tree().get_nodes_in_group("ships"):
						if sh.team == 1 and sh != lark:
							sh.die()
					while not lark.disabled:
						lark.take_damage(lark.max_hull * 0.1, lark.global_position)
					player.global_position = lark.global_position + Vector2(170, 60)
					player.velocity = lark.velocity
					await _wait(0.5)
					story.board()
					await _wait(0.6)
					_shot("look_board_plan")
					story.boarding.pick(0)
					await _wait(2.8)
					_shot("look_board_breach")
					while story.boarding != null and story.boarding.phase == "breach":
						await _wait(0.2)
					await _wait(0.12)
					_shot("look_board_stinger")
					await _wait(2.6)
				elif what == "rift":
					if station_ui.visible:
						undock()
					load_system("marcellus", "aurelia")
					await _wait(0.5)
					var j: Node2D = null
					for b in bodies:
						if b.kind == "jump":
							j = b
					if j:
						player.position = j.global_position + Vector2(320, 120)
					await _wait(1.0)
				else:
					Career.flags["franz_met"] = true
					_go(what)
					await _wait(0.3)
				_shot("look_" + what)
			get_tree().quit()
			return
	# --fast: bigger time steps, so rendered runs (screenshots) finish sooner.
	if "--fast" in OS.get_cmdline_user_args():
		Engine.time_scale = 4.0
	await _wait(0.5)
	print("[merchant] start: day=%.2f credits=%d loan=%d jobs=%d objective=%s" % [Career.day, Career.credits, Career.loan_balance, Career.jobs.size(), Career.objective.get("station", "")])
	_shot("m_flight")
	_go("bones")
	Career.buy("bones", "parts", 20)
	await _wait(0.05)
	_shot("m_station")
	undock()
	_go("drip")
	print("[merchant] at drip: hold=%d/%d job_cargo=%s cargo=%s" % [Career.cargo_used(), Career.cargo_capacity, Career.job_cargo, Career.cargo])
	undock()
	await _wait(0.1)
	_shot("m_drip")
	var target := objective_target()
	print("[merchant] objective points at: %s %s" % [target.kind if target else "none", target.id if target else ""])
	player.position = target.global_position
	player.velocity = Vector2.ZERO
	_try_interact()
	await _wait(3.3)
	_shot("m_arrival")
	print("[merchant] after jump: system=%s" % system_id)
	_go("greenhouse")
	var before := Career.credits
	Career.sell("greenhouse", "parts", 99)
	print("[merchant] delivered: credits=%d (parts sold for %d) flags=%s objective=%s" % [Career.credits, Career.credits - before, Career.flags, Career.objective])
	print("[merchant] friend: met=%s escorts=%s capacity=%d" % [Career.friend.get("met"), escorts.map(func(e): return e.display_name), Career.cargo_capacity])
	undock()
	await _wait(0.3)
	_shot("m_greenhouse")
	Career.day = 6.99
	await _wait(1.0)
	print("[merchant] after week 1: credits=%d loan=%d" % [Career.credits, Career.loan_balance])

	# The Tallyman waits at the Marcellus jump exit.
	load_system("marcellus", "aurelia")
	await _wait(6.0)
	print("[tally] scene=%s ion=%.0f tally_ships=%d engines_dead=%s" % [story.scene, player.ion_t, story._tally.size(), player.ion_t > 0.0])
	_shot("m_tally_fight")
	var waited := 0.0
	while not story.ringing and waited < 60.0:
		await _wait(0.5)
		waited += 0.5
	print("[tally] hail after %.0fs: score=%d player_hull=%d/%d alive=%s" % [waited, Career.flags.get("tally_score", -1), int(player.hull_hp), int(player.max_hull), is_instance_valid(player)])
	_shot("m_tally_ring")
	if "--tally-ignore" not in OS.get_cmdline_user_args():
		story.answer()
		await _wait(1.0)
		_shot("m_tally_hail")
		if "--tally-silent" not in OS.get_cmdline_user_args():
			story.choose(1)
	waited = 0.0
	while story.scene != "" and waited < 90.0:
		await _wait(0.5)
		waited += 0.5
		if story._phase == "navy" and story._t > 3.0 and not Career.flags.has("test_navy_shot"):
			Career.flags["test_navy_shot"] = true
			_shot("m_franz")
	print("[tally] done after %.0fs: tally_done=%s franz_met=%s engines=%s escorts=%d cargo=%s job_cargo=%s" % [waited, Career.flags.get("tally_done"), Career.flags.get("franz_met"), player.ion_t <= 0.0, escorts.size(), Career.cargo, Career.job_cargo])

	# Kessler's board at Four, then the Red Stork near Amber's.
	_go("four")
	Career.take_bounty()
	await _wait(0.05)
	_shot("m_four")
	undock()
	player.position = Data.stations["ambers"]["pos"] + Vector2(300, 0)
	await _wait(1.0)
	var lark: Ship = story._bounty_ship
	print("[bounty] spawned=%s objective=%s" % [lark != null and is_instance_valid(lark), Career.objective.get("station", "")])
	for s in get_tree().get_nodes_in_group("ships"):
		if s.team == 1 and s != lark:
			s.die()
	if lark:
		# Knock it dead in the water, pull alongside, and board until taken.
		while not lark.disabled:
			lark.take_damage(lark.max_hull * 0.1, lark.global_position)
		print("[board] disabled=%s hull=%d/%d" % [lark.disabled, int(lark.hull_hp), int(lark.max_hull)])
		var tries := 0
		while is_instance_valid(lark) and lark.team == 1 and Career.flags.get("marines", 0) > 0 and tries < 4:
			tries += 1
			player.global_position = lark.global_position + Vector2(160, 0)
			player.velocity = lark.velocity
			story.board()
			await _wait(0.6)
			if tries == 1:
				_shot("m_board_plan")
			story.boarding.pick(0)
			var w := 0.0
			while story.boarding != null and story.boarding.phase == "breach" and w < 15.0:
				await _wait(0.5)
				w += 0.5
				if tries == 1 and w == 2.0:
					_shot("m_board_breach")
			await _wait(2.6)
			_shot("m_board_end_%d" % tries)
			await _wait(3.0)
		print("[board] tries=%d alive=%s marines=%d share=%s" % [tries, Career.flags.get("bounty_alive"), Career.flags.get("marines", 0), Career.flags.get("prize_share")])
		if not Career.flags.get("bounty_alive", false) and is_instance_valid(lark):
			lark.die()
	_go("four")
	print("[bounty] killed=%s paid=%s credits=%d" % [Career.flags.get("bounty_killed"), Career.flags.get("bounty_paid"), Career.credits])
	undock()
	_go("four")
	print("[bounty] pitch=%s" % Career.flags.get("franz_pitch"))
	undock()

	# Dez goes down and comes back at the next dock.
	for e in escorts:
		if is_instance_valid(e) and e.is_friend:
			e.die()
	print("[merchant] friend down=%s" % Career.friend.get("down"))
	_go("saltgate")
	print("[merchant] after dock: down=%s escorts=%d" % [Career.friend.get("down"), escorts.size()])

	# Saltgate's bar.
	Career.credits += 2000
	print("[bar] hire fay=%s mersham=%s escorts=%s bond=%s" % [Career.hire("fay"), Career.hire("mersham"), escorts.map(func(e): return e.display_name), Career.flags.get("bond")])
	# Save and load round trip.
	var save_before := [Career.credits, Career.loan_balance, snappedf(Career.day, 0.01), Career.crew.keys(), Career.flags.get("bounty_paid"), Career.friend.get("role")]
	Career.save_game("saltgate")
	Career.credits = 1
	Career.crew = {}
	Career.flags = {}
	var loaded := Career.load_game()
	var save_after := [Career.credits, Career.loan_balance, snappedf(Career.day, 0.01), Career.crew.keys(), Career.flags.get("bounty_paid"), Career.friend.get("role")]
	print("[save] loaded=%s match=%s resume=%s summary=%s\n  before=%s\n  after=%s" % [loaded, str(save_before) == str(save_after), Career.resume_station, Career.save_summary(), save_before, save_after])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.SAVE_PATH))
	await _wait(0.05)
	_shot("m_saltgate")
	undock()

	# Pay it off and go see the gate.
	Career.credits += Career.loan_balance
	_go("counter")
	Career.pay_extra(Career.loan_balance)
	print("[ending] papers=%s loan=%d" % [Career.flags.get("papers"), Career.loan_balance])
	undock()
	load_system("porta_aquila", "tiberine")
	await _wait(0.5)
	for b in bodies:
		if b.kind == "jump" and b.locked:
			player.position = b.global_position
			player.velocity = Vector2.ZERO
	_try_interact()
	print("[ending] scene=%s charging=%s" % [story.scene, jump_charge >= 0.0])
	await _wait(4.0)
	print("[ending] system=%s hud=%s" % [system_id, hud.visible])
	await _wait(10.0)
	_shot("m_crossroads")
	await _wait(14.0)
	print("[ending] phase=%s" % story._phase)
	_shot("m_title")
	print("[merchant] done")
	get_tree().quit()
