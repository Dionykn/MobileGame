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
#     "instance_id": <int>,   # unique runtime ID, never persisted between runs
#     "item":        <dict>,  # full static item dict from StaticData
#     "count":       <int>,   # stack size (see _can_stack)
#   }
#
# Stacking only happens for items that have no meaningful per-instance state,
# i.e. they have no Equip slot, no Durability, and no consumable values.
# Everything else is a stack of 1.
#
# CARRY CAPACITY
# --------------
# Base carry capacity is BASE_CARRY_CAPACITY.
# Each equipped item with an Encumbrance value adds to it.
# The derived value is read via get_carry_capacity().
# ==============================================================================

signal stats_changed
signal item_added(instance: Dictionary)
signal item_updated(instance_id: int, new_count: int)
signal item_removed(instance_id: int)

const SAVE_PATH          := "user://savegame.json"
const BASE_CARRY_CAPACITY := 10.0

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
# Slot keys match the Equip values used in Items.json (case-sensitive).
# "Left hand" and "Right hand" are separate; "Two handed" occupies both at once.
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
# Array of instance Dictionaries (see header comment).
var inventory: Array = []

# Monotonically increasing counter used to assign unique instance IDs at
# runtime. Never saved — instances are rebuilt from the save data on load.
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

# Returns the player's total carry capacity:
# base + Encumbrance values of all currently equipped items.
func get_carry_capacity() -> float:
	var total := BASE_CARRY_CAPACITY
	for slot in equipment:
		var equipped = equipment[slot]
		if equipped == null:
			continue
		var enc = equipped.get("Encumbrance", 0.0)
		total += float(enc)
	return total


# Returns the total weight currently carried in the inventory.
func get_carried_weight() -> float:
	var total := 0.0
	for instance in inventory:
		var w = instance["item"].get("Weight", 0.0)
		total += float(w) * instance["count"]
	return total


# ==============================================================================
# Save / Load
# ==============================================================================

func save_game() -> void:
	# Serialise inventory — instance_ids are runtime-only, so we drop them.
	var inv_serialized: Array = []
	for instance in inventory:
		inv_serialized.append({
			"item_id": instance["item"]["ID"],
			"count":   instance["count"],
		})

	# Serialise equipment — store item IDs only; null slots store null.
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

	# --- Equipment ------------------------------------------------------------
	var saved_equipment: Dictionary = parsed.get("equipment", {})
	for slot in saved_equipment:
		if not equipment.has(slot):
			continue
		var item_id = saved_equipment[slot]
		if item_id == null:
			equipment[slot] = null
		else:
			equipment[slot] = StaticData.get_item(int(item_id))

	# --- Body condition -------------------------------------------------------
	var saved_body: Dictionary = parsed.get("body_condition", {})
	for part in saved_body:
		if body_condition.has(part):
			body_condition[part] = saved_body[part]

	# --- Inventory ------------------------------------------------------------
	# Rebuild instances from saved data. Handles both the new Array format and
	# the old Dictionary format (keyed by item ID string) for backwards compat.
	# Signals are not emitted here — Survivor._ready() reads inventory directly.
	var raw_inventory = parsed.get("inventory", [])
	var entries_to_load: Array = []

	if raw_inventory is Array:
		entries_to_load = raw_inventory
	elif raw_inventory is Dictionary:
		# Old format: { "1001": { "item": {...}, "count": 3 } }
		for key in raw_inventory:
			var old_entry = raw_inventory[key]
			if old_entry is Dictionary:
				entries_to_load.append({
					"item_id": int(key),
					"count":   int(old_entry.get("count", 1)),
				})

	for entry in entries_to_load:
		var item_id: int = int(entry.get("item_id", 0))
		var count:   int = int(entry.get("count",   1))
		var item = StaticData.get_item(item_id)
		if item == null:
			push_warning("PlayerData: saved item ID %d not found in StaticData — skipped." % item_id)
			continue
		var instance := _make_instance(item, count)
		inventory.append(instance)

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


# ==============================================================================
# Inventory helpers
# ==============================================================================

# Creates a new inventory instance dict with a fresh runtime ID.
func _make_instance(item: Dictionary, count: int = 1) -> Dictionary:
	var instance := {
		"instance_id": _next_instance_id,
		"item":        item,
		"count":       count,
	}
	_next_instance_id += 1
	return instance


# Returns true when two items can share a stack.
# Stackable = no Equip slot, no Durability, no consumable fields.
func _can_stack(item: Dictionary) -> bool:
	if item.has("Equip"):
		return false
	if item.has("Durability"):
		return false
	if item.has("Happiness") or item.has("Nutrition") or \
	   item.has("Hydration") or item.has("Endurance"):
		return false
	return true


# Finds an existing stackable instance for this item, or null.
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


# Removes one from the stack (or the whole instance if count reaches 0).
# Returns true on success.
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


# Removes the entire instance regardless of count (e.g. on equip).
func remove_instance(instance_id: int) -> bool:
	for i in inventory.size():
		if inventory[i]["instance_id"] == instance_id:
			inventory.remove_at(i)
			item_removed.emit(instance_id)
			notify_stats_changed()
			return true
	return false


# Returns the instance dict for a given instance_id, or null.
func get_instance(instance_id: int) -> Variant:
	for instance in inventory:
		if instance["instance_id"] == instance_id:
			return instance
	return null


# ==============================================================================
# Equipment helpers
# ==============================================================================

# Returns the valid equip options for an item as an Array of slot strings,
# or an empty Array if the item cannot be equipped.
#
# Slot strings in the JSON / returned array:
#   "Hat", "Top", "Pants", "Shoes", "Gloves", "Backpack", "Sling", "Waist"
#   "Left hand", "Right hand"  — player chooses one hand
#   "Two handed"               — item occupies both hands simultaneously
#
# Items may list several options, e.g. ["Left hand", "Right hand", "Two handed"]
# meaning the player can use it one-handed OR two-handed.
func get_equip_slots(item: Dictionary) -> Array:
	var equip = item.get("Equip", null)
	if equip == null:
		return []
	if equip is Array:
		return equip
	return [equip]


# Returns true if the item fills both hand slots when equipped in the given slot.
func _is_two_handed_slot(slot: String) -> bool:
	return slot == "Two handed"


# Equips an item instance from inventory into the given slot.
# If "Two handed" is passed as the slot, both hand slots are filled.
# Any previously equipped item in the target slot(s) is returned to inventory.
# Returns true on success.
func equip_item(instance_id: int, slot: String) -> bool:
	var instance = get_instance(instance_id)
	if instance == null:
		push_warning("PlayerData.equip_item: instance %d not found." % instance_id)
		return false

	var item: Dictionary  = instance["item"]
	var allowed_slots     := get_equip_slots(item)

	if allowed_slots.is_empty():
		push_warning("PlayerData.equip_item: item '%s' has no Equip field." % item.get("Item Name", "?"))
		return false

	if not allowed_slots.has(slot):
		push_warning("PlayerData.equip_item: slot '%s' not valid for '%s'." % [slot, item.get("Item Name", "?")])
		return false

	# Determine which equipment dictionary keys to fill.
	var slots_to_fill: Array = ["Left hand", "Right hand"] if _is_two_handed_slot(slot) else [slot]

	# Unequip whatever is currently in each target slot first.
	for s in slots_to_fill:
		_unequip_slot_internal(s)

	# Remove from inventory and place into equipment slot(s).
	remove_instance(instance_id)
	for s in slots_to_fill:
		equipment[s] = item

	notify_stats_changed()
	return true


# Unequips the item in the given slot and returns it to inventory.
# If the slot holds a two-handed item, both hand slots are cleared.
func unequip_slot(slot: String) -> bool:
	if not equipment.has(slot):
		push_warning("PlayerData.unequip_slot: unknown slot '%s'." % slot)
		return false
	if equipment[slot] == null:
		return false
	_unequip_slot_internal(slot)
	notify_stats_changed()
	return true


# Clears a slot (and its mirror for two-handed items) and returns the item
# to inventory. Does NOT emit stats_changed — callers handle that.
func _unequip_slot_internal(slot: String) -> void:
	if not equipment.has(slot):
		return
	var item = equipment[slot]
	if item == null:
		return

	# Two-handed items are stored in both hand slots with the same reference.
	# Check the mirror slot to decide whether to clear both.
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
