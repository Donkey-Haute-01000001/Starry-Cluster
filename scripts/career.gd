extends Node
## The player's career state: money, the Charter loan, cargo, time, jobs and
## story flags. An autoload, so it survives jumping between systems.

signal comms(speaker: String, text: String)
signal changed
signal friend_joined
signal friend_back
signal crew_joined(id: String)
signal crew_left(id: String)

var active := false
var credits := 0
var loan_balance := 0
var cargo := {}             ## good id -> tons you own
var job_cargo := {}         ## good id -> tons carried for a job (not yours to sell)
var cargo_capacity := 40
var day := 0.0              ## days since the start; one week = 7 days
var next_payment_day := 7.0
var system_id := "aurelia"
var jobs: Array = []        ## accepted jobs
var flags := {}
var objective := {}         ## {"text": String, "station": String} or empty
## The old friend: name, portrait, role, memory, met, down. Empty until designed.
var friend := {}
var crew := {}              ## hired bar captains: id -> {"down": bool}
var visited := {}           ## system ids you've been to
var _once := {}             ## friend lines that only play once
var _prices := {}           ## station id -> good id -> price this week


func start_merchant(p_friend: Dictionary = {}) -> void:
	active = true
	friend = p_friend.duplicate()
	friend["met"] = false
	friend["down"] = false
	visited = {"aurelia": true}
	crew = {}
	_once = {}
	credits = Data.START_CREDITS
	loan_balance = Data.LOAN_TOTAL
	cargo = {}
	job_cargo = {}
	cargo_capacity = Data.hulls["light_freighter"]["cargo"]
	day = 0.0
	next_payment_day = 7.0
	system_id = "aurelia"
	jobs = []
	flags = {}
	objective = {}
	_roll_prices(1)
	changed.emit()


# --- Time and the loan -----------------------------------------------------

## Advance the clock while flying. Docked time is paused, like Endless Sky.
func advance(delta: float) -> void:
	if not active:
		return
	day += delta / Data.SECONDS_PER_DAY
	if day >= next_payment_day:
		next_payment_day += 7.0
		_weekly_payment()
		_roll_prices(int(day / 7.0) + 1)


func week() -> int:
	return int(day / 7.0) + 1


func _weekly_payment() -> void:
	_pay_wages()
	if loan_balance <= 0:
		return
	var due := mini(Data.LOAN_WEEKLY, loan_balance)
	if credits >= due:
		credits -= due
		loan_balance -= due
		if loan_balance <= 0:
			_paid_off()
		else:
			say("Charlie", Data.charlie["paid"] % [_fmt(due), _fmt(loan_balance)])
	else:
		loan_balance += int(due * Data.LOAN_INTEREST)
		say("Charlie", Data.charlie["missed"])
		friend_say("missed")
	changed.emit()


## Early payoff is allowed at the Counter.
func pay_extra(amount: int) -> void:
	amount = mini(mini(amount, credits), loan_balance)
	if amount <= 0:
		return
	credits -= amount
	loan_balance -= amount
	if loan_balance <= 0:
		_paid_off()
	else:
		friend_say("paid_extra", true)
	changed.emit()


func _paid_off() -> void:
	loan_balance = 0
	flags["paid_off"] = true
	flags["papers"] = true
	say("Charlie", Data.charlie["paid_off"])
	friend_say("paid_off", true)


## Bar captains are on weekly contracts. No pay, and they walk.
func _pay_wages() -> void:
	for id in crew.keys():
		var c: Dictionary = Data.captains[id]
		if credits >= c["wage"]:
			credits -= c["wage"]
		else:
			say(c["name"], Data.captain_lines["unpaid"])
			crew.erase(id)
			crew_left.emit(id)


func hire(id: String) -> bool:
	var c: Dictionary = Data.captains[id]
	if crew.has(id) or credits < c["wage"]:
		return false
	credits -= c["wage"]   # first week up front
	crew[id] = {"down": false}
	say(c["name"], c["hired"])
	crew_joined.emit(id)
	# Hire both and something comes out between them.
	if crew.has("fay") and crew.has("mersham") and not flags.get("bond", false):
		flags["bond"] = true
		var b: Array = Data.captains_bond
		for i in range(0, b.size(), 2):
			say(b[i], b[i + 1])
	changed.emit()
	return true


func crew_with_you(id: String) -> bool:
	return crew.has(id) and not crew[id]["down"]


func captain_down(id: String) -> void:
	if not crew.has(id):
		return
	crew[id]["down"] = true
	say(Data.captains[id]["name"], Data.captain_lines["down"])


func take_bounty() -> void:
	if flags.get("bounty_taken", false):
		return
	flags["bounty_taken"] = true
	set_objective("Hunt the Mud Lark near Amber's, in the outer belt.", Data.bounty["station"])
	changed.emit()


# --- Market ------------------------------------------------------------------

## Prices drift a little each week, around what the station makes or needs.
func _roll_prices(seed_week: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * seed_week
	_prices.clear()
	for sid in Data.stations:
		var st: Dictionary = Data.stations[sid]
		var row := {}
		for g in Data.goods_order:
			var f := 1.0
			if g in st["makes"]:
				f = Data.MAKES_FACTOR
			elif g in st["wants"]:
				f = Data.WANTS_FACTOR
			f *= rng.randf_range(0.94, 1.06)
			row[g] = maxi(1, int(round(Data.goods[g]["base"] * f)))
		_prices[sid] = row


func price(station: String, good: String) -> int:
	return _prices[station][good]


## What you actually pay and get, after your friend's haggling.
func buy_price(station: String, good: String) -> int:
	var f := 1.0
	if friend_with_you() and friend["role"] == "trader":
		f -= 0.03
	return maxi(1, int(floor(price(station, good) * f)))


func sell_price(station: String, good: String) -> int:
	var f := 1.0
	if friend_with_you() and friend["role"] == "trader":
		f += 0.03
	if friend_with_you() and friend["memory"] == "lost" and station == "ambers":
		f += 0.1
	return int(ceil(price(station, good) * f))


func cargo_used() -> int:
	var n := 0
	for g in cargo:
		n += cargo[g]
	for g in job_cargo:
		n += job_cargo[g]
	return n


func cargo_free() -> int:
	return cargo_capacity - cargo_used()


func buy(station: String, good: String, tons: int) -> int:
	var p := buy_price(station, good)
	tons = mini(tons, mini(cargo_free(), credits / p))
	if tons <= 0:
		return 0
	credits -= tons * p
	cargo[good] = cargo.get(good, 0) + tons
	changed.emit()
	return tons


func sell(station: String, good: String, tons: int) -> int:
	tons = mini(tons, cargo.get(good, 0))
	if tons <= 0:
		return 0
	credits += tons * sell_price(station, good)
	cargo[good] -= tons
	if cargo[good] <= 0:
		cargo.erase(good)
	changed.emit()
	return tons


# --- Jobs and the opening -----------------------------------------------------

## Called every time the player docks.
func on_dock(station: String) -> void:
	if station == "counter" and not flags.get("met_charlie", false):
		flags["met_charlie"] = true
		say("Charlie", Data.charlie["first_job"])
		jobs.append({"id": "starter_water", "title": "Starter run: water to the Greenhouse",
			"good": "water", "tons": 20, "from": "drip", "to": "greenhouse", "pay": 1500, "loaded": false})
		_set_objective("Fly to the Drip and pick up 20 tons of water. Dock with F.", "drip")
	for j in jobs.duplicate():
		if j["from"] == station and not j["loaded"]:
			if cargo_free() < j["tons"]:
				say("Dock crew", "We've got your %d tons, but your hold's full. Make room and dock again." % j["tons"])
				continue
			j["loaded"] = true
			job_cargo[j["good"]] = job_cargo.get(j["good"], 0) + j["tons"]
			say("Dock crew", "%d tons of %s loaded for %s." % [j["tons"], Data.goods[j["good"]]["name"].to_lower(), Data.stations[j["to"]]["nick"]])
			if j["id"] == "starter_water":
				_set_objective("Jump to Tiberine and deliver the water to the Greenhouse. Spare room? Buy machine parts at the Bones first.", "greenhouse")
		elif j["to"] == station and j["loaded"]:
			job_cargo[j["good"]] -= j["tons"]
			if job_cargo[j["good"]] <= 0:
				job_cargo.erase(j["good"])
			credits += j["pay"]
			jobs.erase(j)
			if j["id"] == "starter_water":
				flags["starter_done"] = true
				say("Charlie", Data.charlie["job_done"])
				_set_objective("", "")
	# The old friend is waiting at the Greenhouse bar after your first delivery.
	if station == "greenhouse" and flags.get("starter_done", false) and not friend.is_empty() and not friend["met"]:
		_meet_friend()
	elif friend.get("down", false):
		friend["down"] = false
		friend_back.emit()
		friend_say("back")
	if station == "ambers" and friend_with_you() and friend["memory"] == "lost":
		friend_say("callback", true)
	for id in crew:
		if crew[id]["down"]:
			crew[id]["down"] = false
			crew_joined.emit(id)
	# Saltgate's bar: two captains looking for work.
	if station == "saltgate" and not flags.get("bar_pitch", false):
		flags["bar_pitch"] = true
		for id in Data.captain_order:
			say(Data.captains[id]["name"], Data.captains[id]["pitch"])
	# Kessler at Four: the count, the bounty, and later the pitch.
	if station == "four" and flags.get("franz_met", false):
		var first: bool = not flags.get("franz_four", false)
		if first:
			flags["franz_four"] = true
			say("Franz", Data.franz["at_four"])
		if flags.get("bounty_killed", false) and not flags.get("bounty_paid", false):
			flags["bounty_paid"] = true
			credits += Data.bounty["pay"]
			say("Franz", Data.franz["paid"])
			set_objective("", "")
		elif not first and flags.get("bounty_paid", false) and not flags.get("franz_pitch", false):
			flags["franz_pitch"] = true
			say("Franz", Data.franz["pitch"])
	changed.emit()


func _meet_friend() -> void:
	friend["met"] = true
	var role: Dictionary = Data.friend_roles[friend["role"]]
	var mem: Dictionary = Data.friend_memories[friend["memory"]]
	say(friend["name"], Data.FRIEND_MEETING % [player_name(), mem["memory"], role["ship"]])
	if friend["role"] == "trader":
		cargo_capacity += Data.hulls[role["hull"]].get("cargo", 0)
	friend_joined.emit()
	friend_say("joined")


## The player has no name yet; the friend calls you by your old nickname.
func player_name() -> String:
	return friend.get("calls_you", "Cap")


func friend_with_you() -> bool:
	return friend.get("met", false) and not friend.get("down", false)


## A line from the friend. `key` is in Data.friend_lines, or "callback" for the
## shared-memory line. once=true plays it only the first time.
func friend_say(key: String, once := false) -> void:
	if not friend_with_you():
		return
	if once:
		if _once.has(key):
			return
		_once[key] = true
	var text: String = Data.friend_memories[friend["memory"]]["line"] if key == "callback" else Data.friend_lines[key]
	say(friend["name"], text)


func friend_shot_down() -> void:
	if not friend_with_you():
		return
	friend_say("down")
	friend["down"] = true
	changed.emit()


## Called on arriving in a system.
func on_enter_system(id: String) -> void:
	if visited.has(id):
		return
	visited[id] = true
	if friend_with_you() and friend["memory"] == "gate":
		credits += 300
		say(friend["name"], "New sky. Never gets old. Sold our survey data, by the way: 300 credits.")
		changed.emit()


func set_objective(text: String, station: String) -> void:
	_set_objective(text, station)


func _set_objective(text: String, station: String) -> void:
	objective = {} if text == "" else {"text": text, "station": station}


func say(speaker: String, text: String) -> void:
	comms.emit(speaker, text)


## Shortest jump route between systems: the first system to jump to, or "".
func next_hop(from: String, to: String) -> String:
	if from == to:
		return ""
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for j in Data.systems[cur]["jumps"]:
			var n: String = j["to"]
			if j.get("locked", false) or not Data.systems.has(n) or prev.has(n):
				continue
			prev[n] = cur
			if n == to:
				var step := n
				while prev[step] != from:
					step = prev[step]
				return step
			queue.append(n)
	return ""


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func fmt(n: int) -> String:
	return _fmt(n)
