extends Node

const TALLY_FORK := false  ## Tally's job offer: Scrapper/Pirate starts only
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
var strikes := 0              ## missed payments not yet made good; 2 = repo cutter
var arrears := 0              ## overdue amount (already part of loan_balance)
var system_id := "aurelia"
var jobs: Array = []        ## accepted jobs
var flags := {}
var objective := {}         ## {"text": String, "station": String} or empty
## The old friend: name, portrait, role, memory, met, down. Empty until designed.
var friend := {}
var crew := {}              ## hired bar captains: id -> {"down": bool}
var visited := {}           ## system ids you've been to
## Who you are: signed on the Charter's financing agreement.
var pilot := {"name": "", "rig": "", "photo": 0}
var comms_log: Array = []         ## every comms line this career: [day, speaker, text]
var contacts := {}          ## speaker -> true, everyone who has talked to you
var _once := {}             ## friend lines that only play once
var _prices := {}           ## station id -> good id -> price this week


func start_merchant(p_friend: Dictionary = {}, p_pilot: Dictionary = {}) -> void:
	active = true
	pilot = {"name": p_pilot.get("name", "Unnamed"), "rig": p_pilot.get("rig", "Unnamed rig"), "photo": int(p_pilot.get("photo", 0))}
	comms_log = []
	contacts = {}
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
	strikes = 0
	arrears = 0
	system_id = "aurelia"
	jobs = []
	flags = {}
	objective = {}
	_roll_prices(1)
	resume_station = ""
	slot = -1   # new career: gets its own file on the first dock
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
	var owed := mini(due + arrears, loan_balance)
	if credits >= owed:
		credits -= owed
		loan_balance -= owed
		var cleared := strikes > 0
		arrears = 0
		strikes = 0
		if loan_balance <= 0:
			_paid_off()
		elif cleared:
			say("Charlie", Data.charlie["called_off"], true)
		else:
			say("Charlie", Data.charlie["paid"] % [_fmt(owed), _fmt(loan_balance)], true)
	else:
		# A strike: interest on the lien, and the overdue sticks until it's paid.
		loan_balance += int(due * Data.LOAN_INTEREST)
		arrears += due
		strikes += 1
		say("Charlie", Data.charlie["strike1"] if strikes == 1 else Data.charlie["strike2"])
		friend_say("missed" if strikes == 1 else "strike")
	changed.emit()


## The cutter caught you: cargo seized, cash taken against the overdue, fee on the lien.
func repossess() -> Dictionary:
	var seized := cargo_used()
	cargo.clear()
	job_cargo.clear()
	jobs = jobs.filter(func(j): return not j["loaded"])
	var took := mini(credits, arrears)
	credits -= took
	loan_balance -= took
	loan_balance += Data.REPO_FEE
	arrears = 0
	strikes = 0
	flags["repos"] = int(flags.get("repos", 0)) + 1
	say("Charlie", Data.charlie["repossessed"])
	changed.emit()
	return {"seized": seized, "took": took, "fee": Data.REPO_FEE}


## Raiders had you for three days. They took the cargo and the cash; the Charter
## paid to get its rig back and put it on your lien. The clock kept running.
func ransom(downed: int) -> Dictionary:
	var seized := cargo_used()
	cargo.clear()
	job_cargo.clear()
	jobs = jobs.filter(func(j): return not j["loaded"])
	var took := credits
	credits = 0
	var fee := Data.RANSOM_FEE + Data.RANSOM_PER_ESCORT * downed
	loan_balance += fee
	flags["ransoms"] = int(flags.get("ransoms", 0)) + 1
	advance(Data.HELD_DAYS * Data.SECONDS_PER_DAY)
	changed.emit()
	return {"seized": seized, "took": took, "downed": downed, "fee": fee, "n": int(flags["ransoms"])}


## Escorts shot down since your last dock: they come home with you, on the bill.
func downed_escorts() -> int:
	var n := 1 if not friend.is_empty() and friend.get("met", false) and friend.get("down", false) else 0
	for id in crew:
		if crew[id]["down"]:
			n += 1
	return n


## You drove the cutter off. The company bills for that too.
func obstruct() -> void:
	loan_balance += Data.OBSTRUCTION_FEE
	flags["obstructed"] = int(flags.get("obstructed", 0)) + 1
	friend_say("repo_fought", true)
	changed.emit()


# --- The no-questions job ------------------------------------------------------

## This week's sealed-crate job, if one is pinned here.
func shady_offer(station: String) -> Dictionary:
	if station in ["counter", "gatehouse"] or not flags.get("starter_done", false) or loan_balance <= 0:
		return {}
	if int(flags.get("shady_week", 0)) == week() or paymaster_angry():
		return {}
	for j in jobs:
		if j["id"] == "shady":
			return {}
	var here: String = Data.stations[station]["system"]
	var dests: Array = []
	for sid in Data.stations:
		if sid != "gatehouse" and Data.stations[sid]["system"] != here:
			dests.append(sid)
	if dests.is_empty():
		return {}
	dests.sort()
	var to: String = dests[absi(hash(station + str(week()))) % dests.size()]
	return {"id": "shady", "title": "No questions: sealed crates", "good": "sealed", "tons": Data.shady["tons"],
		"from": station, "to": to, "pay": Data.LOAN_WEEKLY, "loaded": true}


func take_shady(j: Dictionary) -> bool:
	if cargo_free() < j["tons"]:
		say("Dock crew", "Six tons won't fit, captain. Make room.", true)
		return false
	flags["shady_week"] = week()
	jobs.append(j)
	job_cargo["sealed"] = job_cargo.get("sealed", 0) + j["tons"]
	friend_say("shady_take" if int(flags.get("shady_done", 0)) == 0 else "shady_again")
	if objective.is_empty():
		set_objective("Deliver the sealed crates to %s. Keep clear of navy patrols." % Data.stations[j["to"]]["nick"], j["to"])
	changed.emit()
	return true


## Navy customs found the crates.
func customs_bust() -> void:
	jobs = jobs.filter(func(j): return j["id"] != "shady")
	job_cargo.erase("sealed")
	var fine := Data.LOAN_WEEKLY
	var cash := mini(credits, fine)
	credits -= cash
	loan_balance += fine - cash
	flags["busted"] = int(flags.get("busted", 0)) + 1
	say("Navy patrol", Data.customs["bust"], true)
	friend_say("shady_caught")
	if str(objective.get("text", "")).begins_with("Deliver the sealed"):
		set_objective("", "")
	changed.emit()


## Early payoff is allowed at the Counter.
func pay_extra(amount: int) -> void:
	amount = mini(mini(amount, credits), loan_balance)
	if amount <= 0:
		return
	credits -= amount
	loan_balance -= amount
	var cleared := false
	if arrears > 0:
		arrears = maxi(0, arrears - amount)
		if arrears == 0:
			strikes = 0
			cleared = true
	if loan_balance <= 0:
		_paid_off()
	elif cleared:
		say("Charlie", Data.charlie["called_off"], true)
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


## A wingman who comes with a side, not a contract.
func join(id: String, quiet := false) -> void:
	if crew.has(id):
		return
	crew[id] = {"down": false}
	if not quiet:
		say(Data.captains[id]["name"], Data.captains[id]["hired"])
	crew_joined.emit(id)
	changed.emit()


# --- The forks -------------------------------------------------------------------

## How the lanes see you: rigs you came back for, minus rigs you picked clean.
func lane_rep() -> int:
	return int(flags.get("rigs_saved", 0)) - int(flags.get("rigs_looted", 0))


func remember(key: String, name: String) -> void:
	var arr: Array = flags.get(key, [])
	if name != "" and not arr.has(name):
		arr.append(name)
	flags[key] = arr


func sign_navy() -> void:
	if flags.get("side", "") != "":
		return
	flags["side"] = "navy"
	say("Franz", Data.forks["navy_signed"])
	# Mbeki reports in flight, not on the dock board: he flies up on your port side as you undock.
	flags["mbeki_intro"] = true
	join("navy_wing", true)


func take_tally_job() -> void:
	if flags.get("side", "") != "" or flags.get("tally_job", false):
		return
	flags["tally_job"] = true
	set_objective("Knock out the Charter hauler leaving Four. Tally's crew does the rest.", "four")
	changed.emit()


func tally_job_done() -> void:
	flags["side"] = "tally"
	flags["tally_job"] = false
	say("Tallyman", Data.forks["tally_done"])
	join("tally_wing")
	loan_balance += 1500
	say("Charlie", Data.forks["charter_heat"], true)
	if str(objective.get("text", "")).begins_with("Knock out the Charter"):
		set_objective("", "")
	changed.emit()


## The paymaster at Amber's knows what you did to his raider.
func paymaster_angry() -> bool:
	return flags.get("bounty_paid", false) and not flags.get("bounty_alive", false) and int(flags.get("shady_done", 0)) > 0


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
	flags["marines"] = Data.bounty["marines"]
	say("Franz", Data.franz["marines"])
	set_objective("Hunt the Red Stork near Amber's, in the outer belt.", Data.bounty["station"])
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
	if lane_rep() <= -2:
		f += 0.04   # dock crews know your rig
	elif lane_rep() >= 2:
		f -= 0.02   # truckers tip you off
	if friend_with_you() and friend["role"] == "trader":
		f -= 0.03
	return maxi(1, int(floor(price(station, good) * f)))


func sell_price(station: String, good: String) -> int:
	var f := 1.0
	if lane_rep() >= 2:
		f += 0.03
	elif lane_rep() <= -2:
		f -= 0.03
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

## Charlie's hail on your first launch: the starter run.
func first_job() -> void:
	if flags.get("met_charlie", false):
		return
	flags["met_charlie"] = true
	say("Charlie", Data.charlie["first_job"])
	jobs.append({"id": "starter_water", "title": "Starter run: water to the Greenhouse",
		"good": "water", "tons": 20, "from": "drip", "to": "greenhouse", "pay": 1500, "loaded": false})
	_set_objective("Fly to the Drip and pick up 20 tons of water. Dock with F.", "drip")


## Called on every arrival in a system: Charlie walks the first run.
func on_arrive(system: String) -> void:
	if system == "tiberine" and job_cargo.has("water") and not flags.get("walk_tiberine", false):
		for j in jobs:
			if j["id"] == "starter_water" and j["loaded"]:
				flags["walk_tiberine"] = true
				say("Charlie", Data.charlie["walk_tiberine"])


## Called every time the player docks.
func on_dock(station: String) -> void:
	if station == "counter":
		first_job()
	for j in jobs.duplicate():
		if j["from"] == station and not j["loaded"]:
			if cargo_free() < j["tons"]:
				say("Dock crew", "We've got your %d tons, but your hold's full. Make room and dock again." % j["tons"], true)
				continue
			j["loaded"] = true
			job_cargo[j["good"]] = job_cargo.get(j["good"], 0) + j["tons"]
			say("Dock crew", "%d tons of %s loaded for %s." % [j["tons"], Data.goods[j["good"]]["name"].to_lower(), Data.stations[j["to"]]["nick"]], true)
			if j["id"] == "starter_water":
				say("Charlie", Data.charlie["walk_loaded"])
				_set_objective("Water to the Greenhouse, in Tiberine. Spare room? Buy parts at the Bones.", "greenhouse")
		elif j["to"] == station and j["loaded"]:
			job_cargo[j["good"]] -= j["tons"]
			if job_cargo[j["good"]] <= 0:
				job_cargo.erase(j["good"])
			credits += j["pay"]
			jobs.erase(j)
			if j["id"] == "shady":
				flags["shady_done"] = int(flags.get("shady_done", 0)) + 1
				friend_say("shady_done", true)
				if str(objective.get("text", "")).begins_with("Deliver the sealed"):
					_set_objective("", "")
			if j["id"] == "starter_water":
				flags["starter_done"] = true
				# After the Margaret, Charlie keeps it short.
				say("Charlie", Data.ahead["charlie_after"] if flags.get("ahead_robbed", false) else Data.charlie["job_done"])
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
	# The Tallyman's offer, in Amber's back room. Off for the Merchant start
	# (Vishnu 2026-11-25: Merchant is locked to the Navy; Scrapper gets the real
	# Franz-or-Tally choice, Pirate is locked to Tally). Kept for those starts.
	if TALLY_FORK and station == "ambers" and flags.get("tally_done", false) and flags.get("franz_met", false) \
			and strikes >= 1 and flags.get("side", "") == "" and not flags.get("tally_offered", false):
		flags["tally_offered"] = true
		say("Tallyman", Data.forks["tally_offer"])
	# Alejandra, from the rig ahead of you, working the Saltgate docks now.
	if station == "saltgate" and flags.get("ahead_done", false) and not flags.get("nell_met", false):
		flags["nell_met"] = true
		var went_in: bool = flags.get("ahead_went_in", false)
		say(Data.ahead["victim"].split(" ")[0], Data.ahead["hollis_bar_saved"] if went_in else Data.ahead["hollis_bar"])
		say(Data.ahead["owner"], Data.ahead["bar_saved"] if went_in else Data.ahead["bar"])
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
			if flags.get("bounty_alive", false):
				credits += Data.bounty["pay_alive"] + int(flags.get("prize_share", 0))
				say("Franz", Data.franz["paid_alive"])
			else:
				credits += Data.bounty["pay"]
				say("Franz", Data.franz["paid"])
			set_objective("", "")
		elif not first and flags.get("bounty_paid", false) and not flags.get("franz_pitch", false):
			flags["franz_pitch"] = true
			say("Franz", Data.franz["pitch"])
			if flags.get("side", "") == "":
				say("Franz", Data.forks["navy_offer"])
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


## Your first name, as signed.
func first_name() -> String:
	var n: String = pilot.get("name", "")
	return n.split(" ")[0] if n != "" else "Captain"


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
	say(friend["name"], text, key not in ["joined"])


func friend_shot_down() -> void:
	if not friend_with_you():
		return
	friend_say("down")
	friend["down"] = true
	changed.emit()


## Called on arriving in a system.
func on_enter_system(id: String) -> void:
	on_arrive(id)
	if visited.has(id):
		return
	visited[id] = true
	if friend_with_you() and friend["memory"] == "gate":
		credits += 300
		say(friend["name"], "New sky. Never gets old. Sold our survey data, by the way: 300 credits.", true)
		changed.emit()


func set_objective(text: String, station: String) -> void:
	_set_objective(text, station)


func _set_objective(text: String, station: String) -> void:
	objective = {} if text == "" else {"text": text, "station": station}


## Is the line being said right now everyday chatter (scrolls by in the
## ticker) rather than a story beat (waits for you)? Read by listeners.
var chatter_now := false


func say(speaker: String, text: String, chatter := false) -> void:
	chatter_now = chatter
	comms_log.append([day, speaker, text])
	if comms_log.size() > 200:
		comms_log.pop_front()
	if speaker != "You" and not (speaker == "Tallyman" and not flags.has("tally_named") and not flags.get("tally_done", false)):
		contacts[speaker] = true  # the Tallyman is filed once he gives his name
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


## Your prize-court cut of the Red Stork's hold, at base prices.
func prize_share(keep: float) -> int:
	var total := 0
	for row in Data.bounty["hold"]:
		total += int(Data.goods[row[0]]["base"]) * int(row[1])
	return int(total * Data.bounty["share"] * keep)


# --- Saving ------------------------------------------------------------------
## Like Endless Sky: the game saves every time you dock, and Continue puts you
## back at that station's counter.

## One file per career (Endless Sky pilots). A new career never touches
## another's file. Each dock keeps the previous file as .bak.
const SAVE_DIR := "user://careers/"
const LEGACY_PATH := "user://merchant_save.txt"
const SAVE_KEYS := ["credits", "loan_balance", "strikes", "arrears", "cargo", "job_cargo", "cargo_capacity", "day",
	"next_payment_day", "system_id", "jobs", "flags", "objective", "friend", "crew", "visited", "_once", "_prices", "pilot", "comms_log", "contacts"]
var resume_station := ""
var slot := -1


static func _path(n: int) -> String:
	return SAVE_DIR + "%d.txt" % n


func save_game(station: String) -> void:
	_migrate_legacy()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if slot < 0:
		slot = _next_slot()
	var d := {"version": 2, "station": station, "start": "merchant", "saved_at": Time.get_unix_time_from_system()}
	for k in SAVE_KEYS:
		d[k] = get(k)
	var path := _path(slot)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(var_to_str(d))


static func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d = str_to_var(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY and d.has("credits") else null


## The file, or its .bak when the file is broken. null if both are.
static func _read_slot(n: int):
	var d = _read(_path(n))
	return d if d != null else _read(_path(n) + ".bak")


static func _slots() -> Array:
	_migrate_legacy()
	var out := []
	for fname in DirAccess.get_files_at(SAVE_DIR):
		if fname.ends_with(".txt") and fname.get_basename().is_valid_int():
			out.append(int(fname.get_basename()))
	out.sort()
	return out


static func _next_slot() -> int:
	var s := _slots()
	return 1 if s.is_empty() else int(s[-1]) + 1


## Pre-slots saves (one merchant_save.txt) become career 1.
static func _migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH):
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var n := 1
	while FileAccess.file_exists(_path(n)):
		n += 1
	DirAccess.rename_absolute(LEGACY_PATH, _path(n))


## Every career on disk, newest played first:
## {slot, pilot, rig, start, where, day, saved_at, damaged}.
static func list_careers() -> Array:
	var out := []
	for n in _slots():
		var d = _read_slot(n)
		if d == null:
			out.append({"slot": n, "damaged": true, "saved_at": FileAccess.get_modified_time(_path(n))})
			continue
		var st: Dictionary = Data.stations.get(d.get("station", ""), {})
		var p: Dictionary = d.get("pilot", {})
		out.append({"slot": n, "damaged": false, "pilot": p.get("name", "Unnamed"), "rig": p.get("rig", ""),
			"start": d.get("start", "merchant"), "where": st.get("nick", "?"), "day": int(d.get("day", 0.0)) + 1,
			"saved_at": float(d.get("saved_at", FileAccess.get_modified_time(_path(n))))})
	out.sort_custom(func(a, b): return a["saved_at"] > b["saved_at"])
	return out


static func has_save() -> bool:
	for c in list_careers():
		if not c["damaged"]:
			return true
	return false


static func _latest() -> Dictionary:
	for c in list_careers():
		if not c["damaged"]:
			return c
	return {}


## Short line for the Continue button: who, where and when.
static func save_summary() -> String:
	var c := _latest()
	return "" if c.is_empty() else "%s · %s, day %d" % [c["pilot"], c["where"], c["day"]]


## Shred a career: its file and backup.
static func delete_career(n: int) -> void:
	for p in [_path(n), _path(n) + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Load a career by slot; -1 = the one played last.
func load_game(n := -1) -> bool:
	if n < 0:
		n = int(_latest().get("slot", -1))
	if n < 0:
		return false
	var d = _read_slot(n)
	if d == null:
		return false
	for k in SAVE_KEYS:
		if d.has(k):
			set(k, d[k])
	resume_station = d.get("station", "")
	slot = n
	active = true
	changed.emit()
	return true
