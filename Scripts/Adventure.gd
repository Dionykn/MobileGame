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


func _ready() -> void:
	_update_location_display()

# ==============================================================================
# Location helpers
# ==============================================================================

# Moves the player back to the Home area and resets step count.
# Called by MainScene when the player taps the Home nav button.
func set_location_to_home() -> void:
	PlayerData.adventure_steps  = 0
	PlayerData.current_location = StaticData.areaData["1"]
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

	# Fallback — should never be reached
	return StaticData.areaData["2"]


# Updates all labels to reflect the current location.
func _update_location_display() -> void:
	var loc : Dictionary = PlayerData.current_location

	var zombie_amount := randi_range(loc["Zombies Min"], loc["Zombies Max"])
	loot_amount        = int(loc["Loot Amount"])

	zombie_label.text   = str(zombie_amount)
	loot_label.text     = str(loot_amount)
	distance_label.text = "%dm" % (PlayerData.adventure_steps * 100)

	btn_loot_area.disabled = (loot_amount == 0)

	# Notify so the status bar location label refreshes via MainScene
	PlayerData.notify_stats_changed()


# ==============================================================================
# Loot helpers
# ==============================================================================

# Picks a random selection of items from the current area's loot table.
# Returns an Array of item Dictionaries. May return an empty Array.
func _pick_random_loot() -> Array:
	var loot_table = PlayerData.current_location.get("Loot Table", null)

	if loot_table == null or loot_amount == 0:
		return []

	# Build a list of possible items from the loot table using StaticData.get_item()
	var possible_items: Array = []
	for item_id in loot_table:
		var item = StaticData.get_item(int(item_id))
		if item != null:
			possible_items.append(item)

	if possible_items.is_empty():
		return []

	# Pick a random number of items up to the area's loot amount, weighted by Rarity.
	# picks can be 0, which will show an empty loot popup — this is intentional.
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


func _on_loot_area_pressed() -> void:
	var found_loot := _pick_random_loot()

	loot_amount -= found_loot.size()
	loot_label.text        = str(loot_amount)
	btn_loot_area.disabled = (loot_amount == 0)

	loot_popup.show_loot(found_loot)
	loot_popup.visible = true


func _on_go_home_pressed() -> void:
	pass


func _on_attack_zombies_pressed() -> void:
	pass


func _on_claim_area_pressed() -> void:
	pass
