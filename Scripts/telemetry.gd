extends Node
## Telemetry — append-only playtest event log.
##
## Listens to semantic gameplay signals on Global and writes ONE JSON file per run
## to user://telemetry/. Nothing in the game knows telemetry exists: it only
## observes signals, so other systems (achievements, tutorials, a future v2) can
## hook the exact same signals later without touching this.
##
## SETUP: add as an Autoload named "Telemetry", placed AFTER "Global" in the
## autoload order (so Global's signals exist when this connects).
##
## All capture is one shape — an event {t, run, fight, turn, type, data} appended
## to a single list. Every question you'll want to ask later (pick rates, damage
## per fight, event choices, workshops) is just a filter over that one stream, so
## you never have to predict the questions now.

const DIR := "user://telemetry/"

var _session : String = ""        # one id per game launch (one tester sitting)
var _run : int = 0                # increments each run; one file per run
var _fight : int = 0              # increments each fight within a run
var _turn : int = 0               # increments each turn within a fight
var _events : Array = []          # the current run's event stream
var _run_meta : Dictionary = {}
var _t0 : int = 0                 # session start ticks, for relative timestamps


func _ready() -> void:
	_session = _new_id()
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(DIR)
	_connect_signals()


## Time-based id — avoids touching the game's seeded RNG, and is unique enough to
## tell one tester's session from another.
func _new_id() -> String:
	return "%d-%05d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec() % 100000]


# ── Signal wiring ──────────────────────────────────────────────────────────
## Connect defensively: a signal that doesn't exist yet just isn't hooked — no
## crash. Add it to Global + emit it at the call site and telemetry picks it up.
func _connect_signals() -> void:
	_try(&"run_started", _on_run_started)
	_try(&"run_ended", _on_run_ended)
	_try(&"fight_started", _on_fight_started)
	_try(&"fight_ended", _on_fight_ended)
	_try(&"time_passed", _on_time_passed)          # already exists
	_try(&"card_played", _on_card_played)          # already exists
	_try(&"player_damaged", _on_player_damaged)
	_try(&"cards_offered", _on_cards_offered)
	_try(&"card_selected", _on_card_selected)
	_try(&"thingy_offered", _on_thingy_offered)
	_try(&"thingy_selected", _on_thingy_selected)
	_try(&"event_option_chosen", _on_event_option_chosen)
	_try(&"card_workshopped", _on_card_workshopped)


func _try(sig: StringName, cb: Callable) -> void:
	if Global.has_signal(sig) and not Global.is_connected(sig, cb):
		Global.connect(sig, cb)


# ── Core logging ───────────────────────────────────────────────────────────
func log_event(type: String, data: Dictionary = {}) -> void:
	_events.append({
		"t": Time.get_ticks_msec() - _t0,
		"run": _run, "fight": _fight, "turn": _turn,
		"type": type, "data": data,
	})


# ── Lifecycle / context ────────────────────────────────────────────────────
func _on_run_started(character_name: String = "", seed_val: int = -1) -> void:
	_run += 1
	_fight = 0
	_turn = 0
	_events = []
	_run_meta = {
		"character": character_name,
		"seed": seed_val,
		"started": Time.get_datetime_string_from_system(),
	}
	log_event("run_started", _run_meta.duplicate())
	_flush()


func _on_run_ended(won: bool = false) -> void:
	log_event("run_ended", {"won": won})
	_flush()


func _on_fight_started(fight_name: String = "", fight_type: String = "", win_condition: String = "") -> void:
	_fight += 1
	_turn = 0
	log_event("fight_started", {"name": fight_name, "type": fight_type, "win": win_condition})


func _on_fight_ended(won: bool = true) -> void:
	log_event("fight_ended", {"won": won})
	_flush()   # incremental save so a crash mid-run keeps completed fights


func _on_time_passed() -> void:
	_turn += 1


# ── Gameplay events ────────────────────────────────────────────────────────
func _on_player_damaged(to_health: int, blocked: int, source: String = "") -> void:
	log_event("damage_taken", {"hp": to_health, "blocked": blocked, "source": source})


func _on_cards_offered(card_names: Array, context: String = "") -> void:
	log_event("cards_offered", {"cards": card_names, "context": context})


func _on_card_selected(card_name: String, context: String = "") -> void:
	log_event("card_selected", {"card": card_name, "context": context})


func _on_thingy_offered(names: Array, context: String = "") -> void:
	log_event("thingy_offered", {"thingies": names, "context": context})


func _on_thingy_selected(thingy_name: String, context: String = "") -> void:
	log_event("thingy_selected", {"thingy": thingy_name, "context": context})


func _on_event_option_chosen(event_name: String, option_text: String) -> void:
	log_event("event_choice", {"event": event_name, "option": option_text})


func _on_card_workshopped(card_name: String, detail: String = "") -> void:
	log_event("card_workshopped", {"card": card_name, "detail": detail})


func _on_card_played(card_data) -> void:
	var n = card_data.card_name if (card_data and "card_name" in card_data) else "?"
	log_event("card_played", {"card": n})


# ── Persistence ────────────────────────────────────────────────────────────
## One file per run: user://telemetry/<session>-run0003.json. Written on every
## flush (run start, each fight end, run end, quit), so a crash loses at most the
## fight in progress.
func _flush() -> void:
	if _run <= 0:
		return
	var path := "%s%s-run%04d.json" % [DIR, _session, _run]
	var payload := {
		"session": _session,
		"run": _run,
		"meta": _run_meta,
		"events": _events,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush()
