extends Node2D
## Combat sandbox: your flagship and escorts against escalating pirate waves.

const ShipScript := preload("res://scripts/ship.gd")
const FxScript := preload("res://scripts/fx.gd")
const StarfieldScript := preload("res://scripts/starfield.gd")
const HudScript := preload("res://scripts/hud.gd")
const WheelScript := preload("res://scripts/tactics_wheel.gd")
const BodyScript := preload("res://scripts/body.gd")
const StationUIScript := preload("res://scripts/station_ui.gd")

const JUMP_CHARGE := 3.0

const COMBAT_RANGE := 1500.0
const WHEEL_TIME_SCALE := 0.2

var world: Node2D
var fx: Node2D
var camera: Camera2D
var hud: Control
var wheel: Control

var player: Ship = null
var escorts: Array = []
var fleet_order := "engage"
var formation := "wedge"
var focus_target: Ship = null
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
var docked_at := ""
var jump_charge := -1.0      ## seconds charged, or -1 when not charging
var jump_target: Node2D = null
var _pirate_t := 45.0
var _merchant_test := false
var _test_t := 0.0

var _wheel_mouse_world := Vector2.ZERO
var _shake := 0.0
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

	merchant = Data.mode == "merchant"
	_merchant_test = "--merchant-test" in OS.get_cmdline_user_args()
	if _merchant_test:
		process_mode = Node.PROCESS_MODE_ALWAYS  # keep the scripted test running while docked
	if merchant:
		station_ui = Control.new()
		station_ui.set_script(StationUIScript)
		station_ui.main = self
		ui.add_child(station_ui)
		Career.comms.connect(hud.on_comms)
		player = spawn_ship("light_freighter", 0, Vector2.ZERO)
		player.is_player = true
		player.controller = PlayerController.new(player, self)
		load_system(Career.system_id, "")
		# The opening: you start docked at the Counter, where Charlie is waiting.
		var st: Dictionary = Data.stations["counter"]
		player.position = st["pos"] + Vector2(0, 120)
		camera.global_position = player.position
		dock("counter")
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
	for b in bodies:
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()
	for s in get_tree().get_nodes_in_group("ships"):
		if s != player:
			s.remove_from_group("ships")
			s.queue_free()
	fx.projectiles.clear()
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
	_pirate_t = randf_range(25.0, 45.0)
	show_message("%s  ·  %s  ·  %s" % [sys["name"], sys["nick"], sys["security"]], 4.0)


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
			if Career.flags.get("papers", false):
				show_message("Your papers check out. The crossroads await... (the ending arrives in a later build)", 4.0)
			else:
				show_message("Gate customs: no Writ of Passage, no jump. Pay off your Charter loan.", 3.5)
			return
		if jump_charge >= 0.0:
			return
		jump_charge = 0.0
		jump_target = b
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
	get_tree().paused = true
	station_ui.open(id)
	Career.on_dock(id)


func undock() -> void:
	if docked_at == "":
		return
	docked_at = ""
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
				jump_charge = -1.0
				_shake = 12.0
				load_system(dest, from)
	# Pirates hide in the rough systems' rocks.
	var danger: float = Data.systems[system_id]["danger"]
	if danger > 0.0 and hostile_count() == 0:
		_pirate_t -= delta
		if _pirate_t <= 0.0:
			_pirate_t = randf_range(70.0, 120.0) / danger
			var from_angle := randf() * TAU
			var c := player.global_position + Vector2.RIGHT.rotated(from_angle) * 1500.0
			for i in 2:
				var s := spawn_ship("raider", 1, c + Vector2(randf_range(-150, 150), randf_range(-150, 150)), from_angle + PI)
				s.controller = AIController.new(s, self)
			show_message("Pirate raiders inbound! Fight, or run for a station.", 3.5)


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


func spawn_projectile(pos: Vector2, angle: float, w: Dictionary, shooter: Ship) -> void:
	fx.spawn_projectile(pos, angle, w, shooter)


func spawn_sparks(pos: Vector2, color: Color, count: int) -> void:
	fx.spawn_sparks(pos, color, count)


func spawn_explosion(pos: Vector2, radius: float, vel: Vector2) -> void:
	fx.spawn_explosion(pos, radius, vel)
	if is_instance_valid(player):
		var d := pos.distance_to(player.global_position)
		_shake = maxf(_shake, clampf(radius * 0.6 * (1.0 - d / 1500.0), 0.0, 22.0))


func _on_ship_destroyed(s: Ship) -> void:
	if s == player:
		player = null
		jump_charge = -1.0
		show_message("", 0.0)
		return
	if s.team == 1:
		kills += 1
	else:
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


## Nearest live enemy of `team` to `from`, limited to `max_dist` from `center` (default: from).
func nearest_enemy(team: int, from: Vector2, max_dist: float, center = null) -> Ship:
	var c: Vector2 = from if center == null else center
	var best: Ship = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == null or not ship.alive or ship.team == team:
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
		"screen":
			offset = Vector2.RIGHT.rotated(TAU * float(i) / n + PI / n) * 150.0
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
		"wedge", "line", "screen":
			formation = id
			show_message("Formation: %s" % id.capitalize(), 1.5)
		"engage":
			fleet_order = "engage"
			show_message("Wingmen: engage at will", 1.5)
		"hold":
			fleet_order = "hold"
			show_message("Wingmen: hold formation", 1.5)
		"focus":
			_order_focus(_wheel_mouse_world)


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
	if event.is_action_pressed("restart") and not is_instance_valid(player):
		Engine.time_scale = 1.0
		if merchant:
			get_tree().change_scene_to_file("res://scenes/start.tscn")
		else:
			get_tree().reload_current_scene()
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
		in_combat = nearest_enemy(0, player.global_position, COMBAT_RANGE) != null
	else:
		in_combat = false

	if focus_target != null and (not is_instance_valid(focus_target) or not focus_target.alive):
		focus_target = null
	if fleet_order == "focus" and focus_target == null:
		fleet_order = "engage"

	if merchant:
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
		var look := (mouse_world() - player.global_position).limit_length(1200.0) * 0.18
		if autotest:
			look = Vector2.ZERO
		var target := player.global_position + look + player.velocity * 0.15
		camera.global_position = camera.global_position.lerp(target, clampf(8.0 * delta, 0.0, 1.0))
	var z := lerpf(camera.zoom.x, _zoom, clampf(6.0 * delta, 0.0, 1.0))
	camera.zoom = Vector2(z, z)
	_shake = maxf(0.0, _shake - 40.0 * delta)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func _autotest_step(delta: float) -> void:
	_autotest_t += delta
	var frame := int(_autotest_t * 60.0)
	# Exercise every order and formation so the AI paths all get run.
	if frame % 1200 == 600:
		var orders := ["engage", "hold", "focus"]
		var forms := ["wedge", "line", "screen"]
		var k := (frame / 1200) % 3
		formation = forms[k]
		if orders[k] == "focus":
			_order_focus(player.global_position if is_instance_valid(player) else Vector2.ZERO)
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
	if _autotest_t >= 120.0 or not is_instance_valid(player):
		print("[autotest] done: wave=%d kills=%d escort_losses=%d player_alive=%s" % [wave, kills, _losses, is_instance_valid(player)])
		get_tree().quit()


## Automated check of the Merchant opening: `-- --merchant-test`.
## Flies the starter job by teleporting between stops and prints the state.
func _merchant_test_step(delta: float) -> void:
	_test_t += delta
	var step := int(_test_t * 60.0)
	var shots_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	match step:
		30:
			print("[merchant] start: day=%.2f credits=%d loan=%d jobs=%d objective=%s" % [Career.day, Career.credits, Career.loan_balance, Career.jobs.size(), Career.objective.get("station", "")])
			if shots_dir != "":
				get_viewport().get_texture().get_image().save_png(shots_dir + "/m_flight.png")
		60:
			player.position = Data.stations["bones"]["pos"] + Vector2(100, 0)
			player.velocity = Vector2.ZERO
			dock("bones")
		62:
			Career.buy("bones", "parts", 20)
			if shots_dir != "":
				get_viewport().get_texture().get_image().save_png(shots_dir + "/m_station.png")
			undock()
		90:
			player.position = Data.stations["drip"]["pos"] + Vector2(100, 0)
			dock("drip")
		92:
			print("[merchant] at drip: hold=%d/%d job_cargo=%s cargo=%s" % [Career.cargo_used(), Career.cargo_capacity, Career.job_cargo, Career.cargo])
			undock()
		99:
			if shots_dir != "":
				get_viewport().get_texture().get_image().save_png(shots_dir + "/m_drip.png")
		100:
			var target := objective_target()
			print("[merchant] objective points at: %s %s" % [target.kind if target else "none", target.id if target else ""])
			player.position = target.global_position
			player.velocity = Vector2.ZERO
			_try_interact()
		290:
			if shots_dir != "":
				get_viewport().get_texture().get_image().save_png(shots_dir + "/m_arrival.png")
		300:
			print("[merchant] after jump: system=%s" % system_id)
			player.position = Data.stations["greenhouse"]["pos"] + Vector2(100, 0)
			dock("greenhouse")
		302:
			var before := Career.credits
			Career.sell("greenhouse", "parts", 99)
			print("[merchant] delivered: credits=%d (parts sold for %d) flags=%s objective=%s" % [Career.credits, Career.credits - before, Career.flags, Career.objective])
			undock()
		318:
			if shots_dir != "":
				get_viewport().get_texture().get_image().save_png(shots_dir + "/m_greenhouse.png")
		320:
			Career.day = 6.99
		400:
			print("[merchant] after week 1: credits=%d loan=%d" % [Career.credits, Career.loan_balance])
			load_system("marcellus", "tiberine")
			_pirate_t = 0.1
		700:
			print("[merchant] marcellus: hostiles=%d player_alive=%s" % [hostile_count(), is_instance_valid(player)])
			if shots_dir != "":
				get_viewport().get_texture().get_image().save_png(shots_dir + "/m_marcellus.png")
			print("[merchant] done")
			get_tree().quit()
