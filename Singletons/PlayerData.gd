extends Node

# ==============================================================================
# PlayerData — Autoload Singleton
# ------------------------------------------------------------------------------
# Single source of truth for all mutable player and world state.
# Stats, inventory, equipment, skills, time and location all live here so any
# script can read or write them without chasing node references across the
# scene tree.
#
# Usage examples:
#   PlayerData.health
#   PlayerData.add_time(0, 30)
#   PlayerData.add_to_inventory(item_dict)
#   PlayerData.set_equipment("hat", item_dict)
# ==============================================================================

# ------------------------------------------------------------------------------
# Emitted whenever any stat or state changes, so the UI can refresh itself.
# ------------------------------------------------------------------------------
signal stats_changed

# ------------------------------------------------------------------------------
# Inventory signals — emitted by add/remove so the UI updates surgically
# instead of rebuilding the whole grid on every stats_changed.
#   item_added   — a brand-new stack appeared during gameplay
#   item_updated — an existing stack's count changed
#   item_removed — a stack was reduced to 0 and erased
# ------------------------------------------------------------------------------
signal item_added(item: Dictionary)
signal item_updated(item_id: int, new_count: int)
signal item_removed(item_id: int)

const SAVE_PATH := "user://savegame.json"
var new_game: bool = true

# --- World / time state -------------------------------------------------------
var days:    int = 1
var hours:   int = 6   # Game starts at 06:00
var minutes: int = 0

# --- Adventure state ----------------------------------------------------------
var current_location: Dictionary = {}
var adventure_steps:  int = 0

# --- Vital stats --------------------------------------------------------------
var health:      float = 100.0
var hydration:   float = 100.0
var nourishment: float = 100.0
var stamina:     float = 100.0
var endurance:   float = 100.0
var happiness:   float = 100.0

# --- Status values (NOT YET IMPLEMENTED) --------------------------------------
#var pain:         float = 0.0
#var intoxication: float = 0.0
#var temperature:  float = 5.0
#var wetness:      float = 0.0
#var sickness:     float = 0.0

# --- Skills (NOT YET IMPLEMENTED) ---------------------------------------------
#var skills: Dictionary = { ... }

# --- Equipment ----------------------------------------------------------------
var equipment: Dictionary = {
	"hat":      null,
	"top":      null,
	"pants":    null,
	"shoes":    null,
	"gloves":   null,
	"backpack": null,
	"sling":    null,
	"waist":    null,
}

# --- Inventory ----------------------------------------------------------------
# Keyed by item ID (int). Each entry holds the item dict and a stack count.
# Example: { 1001: { "item": {...}, "count": 3 } }
# Always use add_to_inventory / remove_from_inventory — never write directly.
var inventory: Dictionary = {}

# --- Body condition -----------------------------------------------------------
var body_condition: Dictionary = {
	"head":       "Healthy",
	"abdomen":    "Healthy",
	"left_arm":   "Healthy",
	"left_hand":  "Healthy",
	"left_leg":   "Healthy",
	"right_arm":  "Healthy",
	"right_hand": "Healthy",
	"right_leg":  "Healthy",
}


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	stats_changed.connect(save_game)
	load_game()


# ==============================================================================
# Save / Load
# ==============================================================================

func save_game() -> void:
	# JSON only supports string keys — convert int inventory keys to strings.
	var inventory_serialized: Dictionary = {}
	for id in inventory:
		inventory_serialized[str(id)] = inventory[id]

	var data := {
		"days":             days,
		"hours":            hours,
		"minutes":          minutes,
		"adventure_steps":  adventure_steps,
		"current_location": current_location,
		"health":           health,
		"hydration":        hydration,
		"nourishment":      nourishment,
		"stamina":          stamina,
		"endurance":        endurance,
		"happiness":        happiness,
		"equipment":        equipment,
		"inventory":        inventory_serialized,
		"body_condition":   body_condition,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("PlayerData: could not open save file for writing — %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return  # No save file yet — keep defaults.

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("PlayerData: could not open save file for reading — %s" % SAVE_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	new_game = false

	if parsed == null or not parsed is Dictionary:
		push_error("PlayerData: save file is corrupt or unreadable.")
		return

	# --- Time & world ---------------------------------------------------------
	days             = int(parsed.get("days",             days))
	hours            = int(parsed.get("hours",            hours))
	minutes          = int(parsed.get("minutes",          minutes))
	adventure_steps  = int(parsed.get("adventure_steps",  adventure_steps))
	current_location = parsed.get("current_location",     current_location)

	# --- Vital stats ----------------------------------------------------------
	health      = float(parsed.get("health",      health))
	hydration   = float(parsed.get("hydration",   hydration))
	nourishment = float(parsed.get("nourishment", nourishment))
	stamina     = float(parsed.get("stamina",     stamina))
	endurance   = float(parsed.get("endurance",   endurance))
	happiness   = float(parsed.get("happiness",   happiness))

	# --- Equipment ------------------------------------------------------------
	var saved_equipment: Dictionary = parsed.get("equipment", {})
	for slot in saved_equipment:
		if equipment.has(slot):
			equipment[slot] = saved_equipment[slot]

	# --- Body condition -------------------------------------------------------
	var saved_body: Dictionary = parsed.get("body_condition", {})
	for part in saved_body:
		if body_condition.has(part):
			body_condition[part] = saved_body[part]

	# --- Inventory ------------------------------------------------------------
	# JSON stringifies int keys — convert back to int on load.
	# No signals emitted here; Survivor._ready() reads PlayerData.inventory
	# directly via _rebuild_inventory_grid() once its signals are connected.
	var saved_inventory: Dictionary = parsed.get("inventory", {})
	for key in saved_inventory:
		inventory[int(key)] = saved_inventory[key]

	notify_stats_changed()


# ==============================================================================
# Time helpers
# ==============================================================================

func add_time(h: int, m: int) -> void:
	minutes += m
	if minutes >= 60:
		hours   += minutes / 60
		minutes  = minutes % 60
	hours += h
	if hours >= 24:
		days  += hours / 24
		hours  = hours % 24
	notify_stats_changed()


# ==============================================================================
# Stat helpers
# ==============================================================================

func notify_stats_changed() -> void:
	stats_changed.emit()


func _clamp_stat(value: float, max_value: float) -> float:
	return clamp(value, 0.0, max_value)


# ==============================================================================
# Inventory helpers
# ==============================================================================

func add_to_inventory(item: Dictionary) -> void:
	var id: int = item["ID"]
	if inventory.has(id):
		inventory[id]["count"] += 1
		item_updated.emit(id, inventory[id]["count"])
	else:
		inventory[id] = { "item": item, "count": 1 }
		item_added.emit(item)
	notify_stats_changed()


func remove_from_inventory(item_id: int) -> bool:
	if not inventory.has(item_id):
		return false
	inventory[item_id]["count"] -= 1
	if inventory[item_id]["count"] <= 0:
		inventory.erase(item_id)
		item_removed.emit(item_id)
	else:
		item_updated.emit(item_id, inventory[item_id]["count"])
	notify_stats_changed()
	return true


# ==============================================================================
# Equipment helpers
# ==============================================================================

func set_equipment(slot: String, item: Dictionary) -> void:
	if equipment.has(slot):
		equipment[slot] = item
		notify_stats_changed()
	else:
		push_warning("PlayerData: unknown equipment slot '%s'" % slot)


func clear_equipment(slot: String) -> void:
	if equipment.has(slot):
		equipment[slot] = null
		notify_stats_changed()
