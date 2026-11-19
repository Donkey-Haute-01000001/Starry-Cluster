extends Node
## The player's career state: money, the Charter loan, cargo, time, jobs and
## story flags. An autoload, so it survives jumping between systems.

signal comms(speaker: String, text: String)
signal changed

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
var _prices := {}           ## station id -> good id -> price this week


func start_merchant() -> void:
	active = true
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
	changed.emit()


func _paid_off() -> void:
	loan_balance = 0
	flags["paid_off"] = true
	flags["papers"] = true
	say("Charlie", Data.charlie["paid_off"])


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
	var p := price(station, good)
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
	credits += tons * price(station, good)
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
			say("Dock crew", "%d tons of %s loaded for the %s." % [j["tons"], Data.goods[j["good"]]["name"].to_lower(), Data.stations[j["to"]]["nick"]])
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
	changed.emit()


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
