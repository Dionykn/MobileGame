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
#     "freshness":   <float>,     # 0–100; fresh food and opened stable food decay over time
#     "portion":     <float>,     # 0–100; how much of the item remains (partial consume)
#     "durability":  <float>,     # 0–100; equipment only; broken at 0
#     "opened":      <bool>,      # true once a stable food container has been opened
#   }
#
# Stacking only happens for items that have no meaningful per-instance state.
# Opened items never stack with unopened ones of the same ID.
#
# FRESHNESS
# ---------
# Fresh food (Loot Category "Fresh food") and opened stable food start at 100
# and decay over time at FOOD_DECAY_PER_MINUTE.
#
# PORTION
# -------
# Starts at 100 for all items. Partial consumption reduces it.
# When portion reaches 0 the item is removed.
#
# DURABILITY
# ----------
# Starts at the item's Durability value (or 100 if unset). At 0 the item is
# broken: equipment effects are nullified but the item stays in inventory for
# recycling or dropping.
#
# CARRY CAPACITY
# --------------
# Base carry capacity is BASE_CARRY_CAPACITY kg.
# Each equipped item with an Encumbrance value adds to it.
# Broken equipped items do NOT contribute encumbrance.
#
# SLEEP
# -----
# Sleep runs in minute-by-minute increments via sleep_minutes().
# Each minute restores ENDURANCE_RESTORE_PER_MINUTE endurance and drains
# nourishment/hydration at the passive (sleeping) rate.
# Sleep is interrupted early when endurance reaches 100 or any tracked vital
# (health, hydration, nourishment, stamina, happiness) drops to 10 or below.
#
# SAVING
# ------
# Normal saves happen on home arrival and departure only.
# A separate resume-only save is written when the app goes to background so
# Android cannot kill a run silently. That save is deleted on clean home-return.
# ==============================================================================

signal stats_changed
signal item_added(instance: Dictionary)
signal item_updated(instance_id: int, new_count: int)
signal item_removed(instance_id: int)

const SAVE_PATH        := "user://savegame.json"
const RESUME_SAVE_PATH := "user://resume.json"
const BASE_CARRY_CAPACITY := 10.0

# 100 freshness / (3 days × 24 h × 60 min) ≈ 0.0231 per in-game minute.
const FOOD_DECAY_PER_MINUTE := 100.0 / (3.0 * 24.0 * 60.0)

# Sleep constants (per in-game minute).
const ENDURANCE_RESTORE_PER_MINUTE  := 100.0 / (8.0 * 60.0)   # full restore in ~8 h
const NOURISHMENT_DRAIN_PER_MINUTE  := 100.0 / (24.0 * 60.0)  # same as awake baseline
const HYDRATION_DRAIN_PER_MINUTE    := 100.0 / (24.0 * 60.0)

# Any vital at or below this triggers early wake-up.
const SLEEP_INTERRUPT_THRESHOLD := 10.0

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
		# Broken items contribute no encumbrance bonus.
		var instance = _get_equipped_instance(slot)
		if instance != null and instance["durability"] <= 0.0:
			continue
		total += float(equipped.get("Encumbrance", 0.0))
	return total


func get_carried_weight() -> float:
	var total := 0.0
	for instance in inventory:
		total += float(instance["item"].get("Weight", 0.0)) * instance["count"]
	return total


# Returns the inventory instance currently filling an equipment slot, or null.
# Equipment stores the item dict only, so we match by reference.
func _get_equipped_instance(slot: String) -> Variant:
	var item = equipment.get(slot)
	if item == null:
		return null
	for instance in inventory:
		if instance["item"] == item:
			return instance
	return null


# ==============================================================================
# Save / Load
# ==============================================================================

func _serialise() -> Dictionary:
	var inv_serialized: Array = []
	for instance in inventory:
		inv_serialized.append({
			"item_id":    instance["item"]["ID"],
			"count":      instance["count"],
			"freshness":  instance["freshness"],
			"portion":    instance["portion"],
			"durability": instance["durability"],
			"opened":     instance["opened"],
		})

	var equip_serialized: Dictionary = {}
	for slot in equipment:
		var eq = equipment[slot]
		equip_serialized[slot] = eq["ID"] if eq != null else null

	return {
		"save_version":     1,
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


func _write_save(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PlayerData: could not open save file for writing — %s" % path)
		return
	file.store_string(JSON.stringify(_serialise(), "\t"))
	file.close()


func save_game() -> void:
	_write_save(SAVE_PATH)
	# Clean up any leftover resume save when we reach a proper save point.
	if FileAccess.file_exists(RESUME_SAVE_PATH):
		DirAccess.remove_absolute(RESUME_SAVE_PATH)


func save_resume() -> void:
	_write_save(RESUME_SAVE_PATH)


func load_game() -> void:
	# Prefer a resume save (mid-run) over a normal save.
	var path := RESUME_SAVE_PATH if FileAccess.file_exists(RESUME_SAVE_PATH) else SAVE_PATH
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("PlayerData: could not open save file for reading — %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	# If the save is missing, corrupt, or from an incompatible version, start fresh.
	if parsed == null or not parsed is Dictionary or not parsed.has("save_version"):
		push_warning("PlayerData: save file incompatible or corrupt — starting new game.")
		return

	new_game = false

	days             = int(parsed.get("days",            days))
	hours            = int(parsed.get("hours",           hours))
	minutes          = int(parsed.get("minutes",         minutes))
	adventure_steps  = int(parsed.get("adventure_steps", adventure_steps))
	current_location = parsed.get("current_location",    current_location)

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
	if not raw_inventory is Array:
		push_warning("PlayerData: inventory data unreadable — starting with empty inventory.")
		raw_inventory = []

	for entry in raw_inventory:
		var item_id:    int   = int(entry.get("item_id",    0))
		var count:      int   = int(entry.get("count",      1))
		var freshness:  float = float(entry.get("freshness",  100.0))
		var portion:    float = float(entry.get("portion",    100.0))
		var durability: float = float(entry.get("durability", 100.0))
		var opened:     bool  = bool(entry.get("opened",      false))
		var item = StaticData.get_item(item_id)
		if item == null:
			push_warning("PlayerData: saved item ID %d not found in StaticData — skipped." % item_id)
			continue
		var instance := _make_instance(item, count, freshness, portion, durability, opened)
		inventory.append(instance)

	notify_stats_changed()


# ==============================================================================
# Time helpers
# ==============================================================================

func add_time(h: int, m: int) -> void:
	var total_minutes := h * 60 + m
	_decay_food(total_minutes)
	minutes += m
	if minutes >= 60:
		hours   += minutes / 60
		minutes  = minutes % 60
	hours += h
	if hours >= 24:
		days  += hours / 24
		hours  = hours % 24
	notify_stats_changed()


func _decay_food(elapsed_minutes: int) -> void:
	var decay := FOOD_DECAY_PER_MINUTE * float(elapsed_minutes)
	for instance in inventory:
		if _instance_decays(instance):
			instance["freshness"] = maxf(instance["freshness"] - decay, 0.0)


# Returns true when this instance should have its freshness decay over time.
func _instance_decays(instance: Dictionary) -> bool:
	if _is_fresh_food(instance["item"]):
		return true
	if _is_stable_food(instance["item"]) and instance["opened"]:
		return true
	return false


# ==============================================================================
# Sleep
# ==============================================================================

# Attempts to sleep for up to max_minutes in-game minutes.
# Processes each minute individually so stat changes are gradual.
# Returns the number of minutes actually slept.
func sleep_minutes(max_minutes: int) -> int:
	var slept := 0
	for _i in max_minutes:
		if endurance >= 100.0:
			break
		if _any_vital_critical():
			break

		# Restore endurance.
		endurance = minf(endurance + ENDURANCE_RESTORE_PER_MINUTE, 100.0)

		# Drain nourishment and hydration.
		nourishment = maxf(nourishment - NOURISHMENT_DRAIN_PER_MINUTE, 0.0)
		hydration   = maxf(hydration   - HYDRATION_DRAIN_PER_MINUTE,   0.0)

		# Advance the clock (this also decays food).
		add_time(0, 1)
		slept += 1

		# Re-check after advancing time (a drain may have crossed the threshold).
		if _any_vital_critical():
			break

	notify_stats_changed()
	return slept


# Returns true if any tracked vital is at or below the interrupt threshold.
# Encumbrance is not a vital and is intentionally excluded.
func _any_vital_critical() -> bool:
	return (
		health      <= SLEEP_INTERRUPT_THRESHOLD or
		hydration   <= SLEEP_INTERRUPT_THRESHOLD or
		nourishment <= SLEEP_INTERRUPT_THRESHOLD or
		stamina     <= SLEEP_INTERRUPT_THRESHOLD or
		happiness   <= SLEEP_INTERRUPT_THRESHOLD
	)


# ==============================================================================
# Stat helpers
# ==============================================================================

func notify_stats_changed() -> void:
	stats_changed.emit()


# ==============================================================================
# Inventory helpers
# ==============================================================================

func _is_fresh_food(item: Dictionary) -> bool:
	var cat = item.get("Loot Category", "")
	if cat is Array:
		return cat.has("Fresh food")
	return cat == "Fresh food"


func _is_stable_food(item: Dictionary) -> bool:
	var cat = item.get("Loot Category", "")
	if cat is Array:
		return cat.has("Stable food")
	return cat == "Stable food"


func _make_instance(
		item:       Dictionary,
		count:      int   = 1,
		freshness:  float = 100.0,
		portion:    float = 100.0,
		durability: float = -1.0,   # -1 means derive from item dict
		opened:     bool  = false) -> Dictionary:
	var dur: float
	if durability < 0.0:
		dur = float(item.get("Durability", 100.0))
	else:
		dur = durability
	var instance := {
		"instance_id": _next_instance_id,
		"item":        item,
		"count":       count,
		"freshness":   freshness,
		"portion":     portion,
		"durability":  dur,
		"opened":      opened,
	}
	_next_instance_id += 1
	return instance


# Items can stack when they have no meaningful per-instance state.
# Opened items never stack with unopened ones.
func _can_stack(item: Dictionary, opened: bool) -> bool:
	if item.has("Equip"):
		return false
	if item.has("Durability"):
		return false
	if item.has("Happiness") or item.has("Nutrition") or \
	   item.has("Hydration") or item.has("Endurance"):
		return false
	# Stable food that has been opened must not stack with sealed units.
	if _is_stable_food(item) and opened:
		return false
	return true


func _find_stack(item: Dictionary, opened: bool) -> Variant:
	if not _can_stack(item, opened):
		return null
	for instance in inventory:
		if instance["item"]["ID"] == item["ID"] and instance["opened"] == opened:
			return instance
	return null


func add_to_inventory(item: Dictionary) -> void:
	var existing = _find_stack(item, false)
	if existing != null:
		existing["count"] += 1
		item_updated.emit(existing["instance_id"], existing["count"])
	else:
		var instance := _make_instance(item)
		inventory.append(instance)
		item_added.emit(instance)
	notify_stats_changed()


# Opens a stable food instance: marks it as opened and gives it a freshness stat.
# Opened instances will not stack with sealed ones.
func open_item(instance_id: int) -> bool:
	var instance = get_instance(instance_id)
	if instance == null:
		return false
	if not _is_stable_food(instance["item"]):
		return false
	if instance["opened"]:
		return false
	instance["opened"]    = true
	instance["freshness"] = 100.0
	notify_stats_changed()
	return true


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
