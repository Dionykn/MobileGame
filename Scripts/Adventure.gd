extends Control

# ==============================================================================
# Adventure — Exploration screen
# ------------------------------------------------------------------------------
# Handles moving between areas, displaying area info, and looting.
#
# Location and step state live in PlayerData. This script only owns
# loot_amount, which is transient per-visit state that does not need to
# persist beyond the current area.
# ==============================================================================

# --- Node references ----------------------------------------------------------
@onready var zombie_label:   Label   = $MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer/Label2
@onready var loot_label:     Label   = $MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer2/Label2
@onready var distance_label: Label   = $MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer3/Label2
@onready var btn_loot_area:  Button  = $MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/LootArea
@onready var loot_popup:     Control = $Loot_tscn

# Transient per-visit loot remaining in the current area.
var loot_amount: int = 0

# Tracks the last location we displayed so stats_changed doesn't reroll
# when unrelated stats (health, time, etc.) fire the signal.
var _last_displayed_location: Dictionary = {}


func _ready() -> void:
	PlayerData.stats_changed.connect(_on_stats_changed)
	_update_location_display()


# ==============================================================================
# stats_changed handler
# ==============================================================================

# Rerolls the location display only when the current location has actually
# changed (e.g. via the debug console). Ignores signals fired for time ticks,
# stat changes, inventory updates, etc.
func _on_stats_changed() -> void:
	if PlayerData.current_location != _last_displayed_location:
		_update_location_display()


# ==============================================================================
# Location helpers
# ==============================================================================

# Moves the player back to the Home area and resets step count.
# Called by MainScene when the player arrives home.
func set_location_to_home() -> void:
	PlayerData.adventure_steps  = 0
	PlayerData.current_location = StaticData.get_area(1)
	_update_location_display()


# Picks a random area from areaData weighted by the Rarity field.
# Area "1" (Home) is excluded — it is not a valid exploration target.
# Higher Rarity value = more likely to appear.
func _pick_random_location() -> Dictionary:
	var total_weight := 0.0
	for key in StaticData.areaData:
		if key == "1":
			continue
		total_weight += float(StaticData.areaData[key]["Rarity"])

	var roll        := randf() * total_weight
	var accumulated := 0.0
	for key in StaticData.areaData:
		if key == "1":
			continue
		var area: Dictionary = StaticData.areaData[key]
		accumulated += float(area["Rarity"])
		if accumulated >= roll:
			return area

	# Fallback — should never be reached.
	return StaticData.get_area(2)


# Updates all labels to reflect the current location and rerolls transient
# per-visit values (zombie count, available loot).
# Does NOT call notify_stats_changed() — callers that need the status bar
# to reflect a new location must emit that signal themselves.
func _update_location_display() -> void:
	var loc: Dictionary = PlayerData.current_location

	var zombie_amount := randi_range(
		int(loc.get("Zombies Min", 0)),
		int(loc.get("Zombies Max", 0))
	)
	loot_amount = int(loc.get("Loot Amount", 0))

	zombie_label.text   = str(zombie_amount)
	loot_label.text     = str(loot_amount)
	distance_label.text = "%dm" % (PlayerData.adventure_steps * 100)

	btn_loot_area.disabled = (loot_amount == 0)

	_last_displayed_location = PlayerData.current_location


# ==============================================================================
# Loot helpers
# ==============================================================================

# Picks a random selection of items from the current area's loot table.
# Returns an Array of item Dictionaries. May return an empty Array.
func _pick_random_loot() -> Array:
	var loot_table = PlayerData.current_location.get("Loot Table", null)

	if loot_table == null or loot_amount == 0:
		return []

	var possible_items: Array = []
	for item_id in loot_table:
		var item = StaticData.get_item(int(item_id))
		if item != null:
			possible_items.append(item)

	if possible_items.is_empty():
		return []

	var loot:  Array = []
	var picks := randi() % (loot_amount + 1)
	for _i in picks:
		var total_weight := 0.0
		for item in possible_items:
			total_weight += float(item["Rarity"])

		var roll        := randf() * total_weight
		var accumulated := 0.0
		for item in possible_items:
			accumulated += float(item["Rarity"])
			if roll < accumulated:
				loot.append(item)
				break

	return loot


# ==============================================================================
# Button handlers (wired in the editor)
# ==============================================================================

func _on_next_area_pressed() -> void:
	PlayerData.add_time(0, 30)
	PlayerData.adventure_steps  += 1
	PlayerData.current_location  = _pick_random_location()
	_update_location_display()
	# Notify so the status bar location label refreshes.
	PlayerData.notify_stats_changed()


func _on_loot_area_pressed() -> void:
	var found_loot := _pick_random_loot()

	loot_amount -= found_loot.size()
	loot_label.text        = str(loot_amount)
	btn_loot_area.disabled = (loot_amount == 0)

	loot_popup.show_loot(found_loot)
	loot_popup.visible = true


func _on_go_home_pressed() -> void:
	# TODO: implement "turn around" — subtract adventure steps one at a time,
	# passing through random areas and advancing time until steps reach zero.
	pass


func _on_attack_zombies_pressed() -> void:
	# TODO: implement combat.
	pass


func _on_claim_area_pressed() -> void:
	# TODO: implement area claiming.
	pass
