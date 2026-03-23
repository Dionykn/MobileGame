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


# --- World / time state -------------------------------------------------------
var days:    int = 1
var hours:   int = 6   # Game starts at 06:00
var minutes: int = 0

# --- Adventure state ----------------------------------------------------------
var current_location: Dictionary = {}
var adventure_steps:  int = 0

# --- Vital stats --------------------------------------------------------------
# Each stat is a float so gradual changes are smooth.
# Ranges are noted in comments; enforce them through the setters below.

var health:      float = 100.0  # 0–100. Reaches 0 = death.
var hydration:   float = 100.0  # 0–100. Low = reduced carry capacity, then death.
var nourishment: float = 100.0  # 0–100. Low = reduced strength and healing.
var stamina:     float = 100.0  # 0–100. Low = reduced speed and combat.
var happiness:   float = 100.0  # 0–100. Low = slower action speed.

# --- Status values ------------------------------------------------------------
var pain:         float = 0.0   # 0–5.   High = reduced speed. Blocks sleep above minor pain.
var intoxication: float = 0.0   # 0–10.  High = spotted more easily, reduced combat.
var temperature:  float = 5.0   # 0–10.  Target is 5 (≈37 °C). Too high or too low causes effects.
var wetness:      float = 0.0   # 0–5.   Lowers temperature and reduces clothing insulation.
var sickness:     float = 0.0   # 0–5.   Raises temperature, reduces strength, drains health.

# --- Skills -------------------------------------------------------------------
# Each skill is a level integer starting at 0.
var skills: Dictionary = {
	"Fitness":      0,
	"Strength":     0,
	"Sprinting":    0,
	"Light-footed": 0,
	"Nimble":       0,
	"Sneaking":     0,
	"Axe":          0,
	"L.Blunt":      0,
	"S.Blunt":      0,
	"L.Blade":      0,
	"S.Blade":      0,
	"Maintenance":  0,
	"Carpentry":    0,
	"Cooking":      0,
	"Farming":      0,
	"First Aid":    0,
	"Electrical":   0,
	"Metalworking": 0,
	"Mechanics":    0,
	"Tailoring":    0,
	"Aiming":       0,
	"Reloading":    0,
	"Fishing":      0,
	"Foraging":     0,
	"Trapping":     0,
}

# --- Equipment ----------------------------------------------------------------
# Each slot holds either null (empty) or an item Dictionary from StaticData.
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
# A flat Array of item Dictionaries. No fixed size yet — carry capacity will
# be enforced here once the weight system is implemented.
var inventory: Array = []

# --- Body condition -----------------------------------------------------------
# Each body part holds a status string. Expanded when wound system is added.
var body_condition: Dictionary = {
	"head":      "Healthy",
	"abdomen":   "Healthy",
	"left_arm":  "Healthy",
	"right_arm": "Healthy",
	"left_leg":  "Healthy",
	"right_leg": "Healthy",
}


# ==============================================================================
# Time helpers
# ==============================================================================

# Advances time by the given hours and minutes, handling carry correctly.
# Always use this instead of writing to hours/minutes directly.
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

# Call this after changing any stat to notify the UI.
func notify_stats_changed() -> void:
	stats_changed.emit()


# Clamps a value between 0 and a given maximum.
func _clamp_stat(value: float, max_value: float) -> float:
	return clamp(value, 0.0, max_value)


# ==============================================================================
# Inventory helpers
# ==============================================================================

# Adds an item dictionary to the inventory and notifies the UI.
func add_to_inventory(item: Dictionary) -> void:
	inventory.append(item)
	notify_stats_changed()


# Removes the first occurrence of an item with the given ID from inventory.
# Returns true if removed, false if not found.
func remove_from_inventory(item_id: int) -> bool:
	for i in inventory.size():
		if inventory[i].get("ID") == item_id:
			inventory.remove_at(i)
			notify_stats_changed()
			return true
	return false


# ==============================================================================
# Equipment helpers
# ==============================================================================

# Equips an item to the given slot. Slot names match the equipment Dictionary keys.
func set_equipment(slot: String, item: Dictionary) -> void:
	if equipment.has(slot):
		equipment[slot] = item
		notify_stats_changed()
	else:
		push_warning("PlayerData: unknown equipment slot '%s'" % slot)


# Clears a slot (unequips).
func clear_equipment(slot: String) -> void:
	if equipment.has(slot):
		equipment[slot] = null
		notify_stats_changed()
