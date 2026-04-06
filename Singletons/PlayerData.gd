extends Node

# ==============================================================================
# PlayerData — Autoload Singleton
# ------------------------------------------------------------------------------
# Single source of truth for all mutable player and world state.
#
# INVENTORY MODEL
# ---------------
# Each picked-up item is a unique *instance* stored in `inventory` as an Array.
# An instance looks like:
#
#   {
#     "instance_id": <int>,       # unique runtime ID, never persisted between runs
#     "item":        <dict>,      # full static item dict from StaticData
#     "count":       <int>,       # stack size (see _can_stack)
#     "freshness":   <float>,     # 0–100; only meaningful for fresh food (decays over time)
#     "portion":     <float>,     # 0–100; how much of the item remains (partial consume)
#   }
#
# Stacking only happens for items that have no meaningful per-instance state,
# i.e. they have no Equip slot, no Durability, and no consumable values.
# Everything else is a stack of 1.
#
# FRESHNESS
# ---------
# Fresh food (Loot Category "Fresh food") starts at 100 and decays over time.
# FRESH_FOOD_DECAY_PER_MINUTE controls the rate; at the default value food
# fully spoils after 3 in-game days.
#
# PORTION
# -------
# Starts at 100 for all items. Partial consumption reduces it (half → 50,
# quarter → 75 → 50 → 25 → 0). When portion reaches 0 the item is removed.
# Equipment shows Durability from the item dict instead (future feature).
#
# CARRY CAPACITY
# --------------
# Base carry capacity is BASE_CARRY_CAPACITY kg.
# Each equipped item with an Encumbrance value adds to it.
# ==============================================================================

signal stats_changed
signal item_added(instance: Dictionary)
signal item_updated(instance_id: int, new_count: int)
signal item_removed(instance_id: int)

const SAVE_PATH           := "user://savegame.json"
const BASE_CARRY_CAPACITY := 10.0
# 100 freshness / (3 days × 24 h × 60 min) ≈ 0.0231 per in-game minute.
const FRESH_FOOD_DECAY_PER_MINUTE := 100.0 / (3.0 * 24.0 * 60.0)

var new_game: bool = true

# --- World / time state -------------------------------------------------------
var days:    int = 1
var hours:   int = 6
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

# --- Equipment ----------------------------------------------------------------
var equipment: Dictionary = {
	"Hat":        null,
	"Top":        null,
	"Pants":      null,
	"Shoes":      null,
	"Gloves":     null,
	"Backpack":   null,
	"Sling":      null,
	"Waist":      null,
	"Left hand":  null,
	"Right hand": null,
}

# --- Inventory ----------------------------------------------------------------
var inventory: Array = []
var _next_instance_id: int = 1

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
# Carry capacity
# ==============================================================================

func get_carry_capacity() -> float:
	var total := BASE_CARRY_CAPACITY
	for slot in equipment:
		var equipped = equipment[slot]
		if equipped == null:
			continue
		total += float(equipped.get("Encumbrance", 0.0))
	return total


func get_carried_weight() -> float:
	var total := 0.0
	for instance in inventory:
		total += float(instance["item"].get("Weight", 0.0)) * instance["count"]
	return total


# ==============================================================================
# Save / Load
# ==============================================================================

func save_game() -> void:
	var inv_serialized: Array = []
	for instance in inventory:
		inv_serialized.append({
			"item_id":   instance["item"]["ID"],
			"count":     instance["count"],
			"freshness": instance["freshness"],
			"portion":   instance["portion"],
		})

	var equip_serialized: Dictionary = {}
	for slot in equipment:
		var eq = equipment[slot]
		equip_serialized[slot] = eq["ID"] if eq != null else null

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
		"equipment":        equip_serialized,
		"inventory":        inv_serialized,
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
		return

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

	days             = int(parsed.get("days",             days))
	hours            = int(parsed.get("hours",            hours))
	minutes          = int(parsed.get("minutes",          minutes))
	adventure_steps  = int(parsed.get("adventure_steps",  adventure_steps))
	current_location = parsed.get("current_location",     current_location)

	health      = float(parsed.get("health",      health))
	hydration   = float(parsed.get("hydration",   hydration))
	nourishment = float(parsed.get("nourishment", nourishment))
	stamina     = float(parsed.get("stamina",     stamina))
	endurance   = float(parsed.get("endurance",   endurance))
	happiness   = float(parsed.get("happiness",   happiness))

	var saved_equipment: Dictionary = parsed.get("equipment", {})
	for slot in saved_equipment:
		if not equipment.has(slot):
			continue
		var item_id = saved_equipment[slot]
		equipment[slot] = null if item_id == null else StaticData.get_item(int(item_id))

	var saved_body: Dictionary = parsed.get("body_condition", {})
	for part in saved_body:
		if body_condition.has(part):
			body_condition[part] = saved_body[part]

	var raw_inventory = parsed.get("inventory", [])
	var entries_to_load: Array = []

	if raw_inventory is Array:
		entries_to_load = raw_inventory
	elif raw_inventory is Dictionary:
		# Backwards-compat with old dict format.
		for key in raw_inventory:
			var old_entry = raw_inventory[key]
			if old_entry is Dictionary:
				entries_to_load.append({
					"item_id":   int(key),
					"count":     int(old_entry.get("count", 1)),
					"freshness": float(old_entry.get("freshness", old_entry.get("condition", 100.0))),
					"portion":   float(old_entry.get("portion", 100.0)),
				})

	for entry in entries_to_load:
		var item_id:   int   = int(entry.get("item_id",   0))
		var count:     int   = int(entry.get("count",     1))
		var freshness: float = float(entry.get("freshness", 100.0))
		var portion:   float = float(entry.get("portion",   100.0))
		var item = StaticData.get_item(item_id)
		if item == null:
			push_warning("PlayerData: saved item ID %d not found in StaticData — skipped." % item_id)
			continue
		var instance := _make_instance(item, count, freshness, portion)
		inventory.append(instance)

	notify_stats_changed()


# ==============================================================================
# Time helpers
# ==============================================================================

func add_time(h: int, m: int) -> void:
	var total_minutes := h * 60 + m
	_decay_fresh_food(total_minutes)

	minutes += m
	if minutes >= 60:
		hours   += minutes / 60
		minutes  = minutes % 60
	hours += h
	if hours >= 24:
		days  += hours / 24
		hours  = hours % 24
	notify_stats_changed()


func _decay_fresh_food(elapsed_minutes: int) -> void:
	var decay := FRESH_FOOD_DECAY_PER_MINUTE * float(elapsed_minutes)
	for instance in inventory:
		if _is_fresh_food(instance["item"]):
			instance["freshness"] = maxf(instance["freshness"] - decay, 0.0)


# ==============================================================================
# Stat helpers
# ==============================================================================

func notify_stats_changed() -> void:
	stats_changed.emit()


# ==============================================================================
# Inventory helpers
# ==============================================================================

# Returns true when item belongs to the "Fresh food" loot category.
func _is_fresh_food(item: Dictionary) -> bool:
	var cat = item.get("Loot Category", "")
	if cat is Array:
		return cat.has("Fresh food")
	return cat == "Fresh food"


func _make_instance(
		item:      Dictionary,
		count:     int   = 1,
		freshness: float = 100.0,
		portion:   float = 100.0) -> Dictionary:
	var instance := {
		"instance_id": _next_instance_id,
		"item":        item,
		"count":       count,
		"freshness":   freshness,
		"portion":     portion,
	}
	_next_instance_id += 1
	return instance


func _can_stack(item: Dictionary) -> bool:
	if item.has("Equip"):
		return false
	if item.has("Durability"):
		return false
	if item.has("Happiness") or item.has("Nutrition") or \
	   item.has("Hydration") or item.has("Endurance"):
		return false
	return true


func _find_stack(item: Dictionary) -> Variant:
	if not _can_stack(item):
		return null
	for instance in inventory:
		if instance["item"]["ID"] == item["ID"]:
			return instance
	return null


func add_to_inventory(item: Dictionary) -> void:
	var existing = _find_stack(item)
	if existing != null:
		existing["count"] += 1
		item_updated.emit(existing["instance_id"], existing["count"])
	else:
		var instance := _make_instance(item)
		inventory.append(instance)
		item_added.emit(instance)
	notify_stats_changed()


func remove_from_inventory(instance_id: int) -> bool:
	for i in inventory.size():
		var instance: Dictionary = inventory[i]
		if instance["instance_id"] != instance_id:
			continue
		instance["count"] -= 1
		if instance["count"] <= 0:
			inventory.remove_at(i)
			item_removed.emit(instance_id)
		else:
			item_updated.emit(instance_id, instance["count"])
		notify_stats_changed()
		return true
	return false


func remove_instance(instance_id: int) -> bool:
	for i in inventory.size():
		if inventory[i]["instance_id"] == instance_id:
			inventory.remove_at(i)
			item_removed.emit(instance_id)
			notify_stats_changed()
			return true
	return false


func get_instance(instance_id: int) -> Variant:
	for instance in inventory:
		if instance["instance_id"] == instance_id:
			return instance
	return null


# ==============================================================================
# Equipment helpers
# ==============================================================================

func get_equip_slots(item: Dictionary) -> Array:
	var equip = item.get("Equip", null)
	if equip == null:
		return []
	if equip is Array:
		return equip
	return [equip]


func _is_two_handed_slot(slot: String) -> bool:
	return slot == "Two handed"


func equip_item(instance_id: int, slot: String) -> bool:
	var instance = get_instance(instance_id)
	if instance == null:
		push_warning("PlayerData.equip_item: instance %d not found." % instance_id)
		return false

	var item: Dictionary = instance["item"]
	var allowed_slots    := get_equip_slots(item)

	if allowed_slots.is_empty():
		push_warning("PlayerData.equip_item: item '%s' has no Equip field." % item.get("Item Name", "?"))
		return false

	if not allowed_slots.has(slot):
		push_warning("PlayerData.equip_item: slot '%s' not valid for '%s'." % [slot, item.get("Item Name", "?")])
		return false

	var slots_to_fill: Array = ["Left hand", "Right hand"] if _is_two_handed_slot(slot) else [slot]

	for s in slots_to_fill:
		_unequip_slot_internal(s)

	remove_instance(instance_id)
	for s in slots_to_fill:
		equipment[s] = item

	notify_stats_changed()
	return true


func unequip_slot(slot: String) -> bool:
	if not equipment.has(slot):
		push_warning("PlayerData.unequip_slot: unknown slot '%s'." % slot)
		return false
	if equipment[slot] == null:
		return false
	_unequip_slot_internal(slot)
	notify_stats_changed()
	return true


func _unequip_slot_internal(slot: String) -> void:
	if not equipment.has(slot):
		return
	var item = equipment[slot]
	if item == null:
		return

	if slot == "Left hand" and equipment["Right hand"] == item:
		equipment["Left hand"]  = null
		equipment["Right hand"] = null
	elif slot == "Right hand" and equipment["Left hand"] == item:
		equipment["Left hand"]  = null
		equipment["Right hand"] = null
	else:
		equipment[slot] = null

	var instance := _make_instance(item)
	inventory.append(instance)
	item_added.emit(instance)
