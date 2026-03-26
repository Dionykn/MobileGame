extends Control

# ==============================================================================
# DebugConsole — In-game command line for adjusting PlayerData values
# ------------------------------------------------------------------------------
# Toggle with the "toggle_debug_console" input action.
# All commands are lowercase. Type "help" to list them.
# ==============================================================================

@onready var line_edit:        LineEdit        = $Panel/VBoxContainer/LineEdit
@onready var history_label:    Label           = $Panel/VBoxContainer/ScrollContainer/MarginContainer/HistoryLabel
@onready var scroll_container: ScrollContainer = $Panel/VBoxContainer/ScrollContainer

# Separate histories: display shows everything; input_history is for arrow-key recall.
var display_history: Array[String] = []
var input_history:   Array[String] = []
var history_index:   int  = -1
var is_visible:      bool = false


func _ready() -> void:
	hide()
	line_edit.placeholder_text = "Enter command... (type 'help' for commands)"
	_add_to_display("Debug Console ready. Type 'help' for commands.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_console"):
		toggle_console()
		accept_event()


func toggle_console() -> void:
	is_visible = !is_visible
	if is_visible:
		show()
		line_edit.grab_focus()
	else:
		hide()
		line_edit.release_focus()


# ------------------------------------------------------------------------------
# Display helpers
# ------------------------------------------------------------------------------

func _add_to_display(text: String) -> void:
	display_history.append(text)
	# Keep the rolling buffer to 50 lines so it never grows unbounded.
	if display_history.size() > 50:
		display_history.pop_front()
	_update_display()


func _update_display() -> void:
	history_label.text = ""
	for line in display_history:
		history_label.text += line + "\n"
	# Scroll to the bottom after the layout pass finishes.
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value


# ------------------------------------------------------------------------------
# Input handling
# ------------------------------------------------------------------------------

func _on_line_edit_text_submitted(command: String) -> void:
	if command.is_empty():
		return

	input_history.append(command)
	_add_to_display("> " + command)
	_process_command(command.strip_edges().to_lower())

	line_edit.clear()
	history_index = -1


func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				# Walk backwards through input history.
				if history_index < input_history.size() - 1:
					history_index += 1
					line_edit.text = input_history[input_history.size() - 1 - history_index]
					line_edit.caret_column = line_edit.text.length()
					accept_event()
			KEY_DOWN:
				# Walk forwards (towards most recent).
				if history_index > 0:
					history_index -= 1
					line_edit.text = input_history[input_history.size() - 1 - history_index]
					line_edit.caret_column = line_edit.text.length()
				elif history_index == 0:
					history_index = -1
					line_edit.text = ""
				accept_event()


# ------------------------------------------------------------------------------
# Command dispatcher
# ------------------------------------------------------------------------------

func _process_command(command: String) -> void:
	# Split on spaces; drop empty tokens so double-spaces don't cause issues.
	var parts_packed := command.split(" ", false)
	var parts: Array[String] = []
	for part in parts_packed:
		parts.append(part)

	var cmd: String = parts[0] if parts.size() > 0 else ""

	match cmd:
		"help":
			_show_help()

		"set":
			# set [stat] [value]
			if parts.size() >= 3:
				_set_stat(parts[1], parts[2])
			else:
				_add_to_display("Usage: set [stat] [value]")

		"add":
			# add [stat] [value]
			if parts.size() >= 3:
				_add_stat(parts[1], parts[2])
			else:
				_add_to_display("Usage: add [stat] [value]")

		"time":
			# time [h] [m]  OR  time set [h] [m] [d]
			if parts.size() >= 2:
				if parts[1] == "set":
					_set_time(parts)
				else:
					_add_time(parts)
			else:
				_add_to_display("Usage: time [hours] [minutes]  OR  time set [hours] [minutes] [days]")

		"inv":
			# inv add [id] [count]  OR  inv remove [id] [count]
			if parts.size() >= 3:
				if parts[1] == "add":
					_inv_add(parts)
				elif parts[1] == "remove":
					_inv_remove(parts)
				else:
					_add_to_display("Usage: inv add [id] [count]  OR  inv remove [id] [count]")
			else:
				_add_to_display("Usage: inv add [id] [count]  OR  inv remove [id] [count]")

		"equip":
			# equip [slot] [item_id]
			if parts.size() >= 3:
				_equip_item(parts[1], parts[2])
			else:
				_add_to_display("Usage: equip [slot] [item_id]")

		"unequip":
			# unequip [slot]
			if parts.size() >= 2:
				_unequip_item(parts[1])
			else:
				_add_to_display("Usage: unequip [slot]")

		"loc":
			# loc list  OR  loc [id]
			if parts.size() >= 2:
				if parts[1] == "list":
					_list_locations()
				else:
					_set_location(parts[1])
			else:
				_add_to_display("Usage: loc [id]  OR  loc list")

		"reset":
			# reset player | inv | all
			if parts.size() >= 2:
				match parts[1]:
					"player": _reset_player()
					"inv":    _reset_inventory()
					"all":    _reset_all()
					_:        _add_to_display("Usage: reset [player/inv/all]")
			else:
				_add_to_display("Usage: reset [player/inv/all]")

		"health", "hp":
			if parts.size() >= 2:
				_set_stat("health", parts[1])
			else:
				_add_to_display("Usage: health [value]")

		"stamina", "stam":
			if parts.size() >= 2:
				_set_stat("stamina", parts[1])
			else:
				_add_to_display("Usage: stamina [value]")

		"clear":
			display_history.clear()
			_add_to_display("Debug Console ready. Type 'help' for commands.")

		"close", "exit":
			toggle_console()

		_:
			_add_to_display("Unknown command: %s. Type 'help' for available commands." % cmd)


# ------------------------------------------------------------------------------
# Help text
# ------------------------------------------------------------------------------

func _show_help() -> void:
	_add_to_display("=== Debug Console Commands ===")
	_add_to_display("set [stat] [value]       - Set a stat to an exact value")
	_add_to_display("add [stat] [value]       - Add (or subtract) from a stat")
	_add_to_display("  Stats: health, hydration, nourishment, stamina, endurance, happiness")
	_add_to_display("time [h] [m]             - Add hours and minutes to current time")
	_add_to_display("time set [h] [m] [d]     - Set time directly (days optional)")
	_add_to_display("inv add [id] [count]     - Add item by ID (count defaults to 1)")
	_add_to_display("inv remove [id] [count]  - Remove item by ID (count defaults to 1)")
	_add_to_display("equip [slot] [id]        - Equip item by ID into a slot")
	_add_to_display("unequip [slot]           - Clear an equipment slot")
	_add_to_display("  Slots: hat, top, pants, shoes, gloves, backpack, sling, waist")
	_add_to_display("loc [id]                 - Teleport to area by numeric ID")
	_add_to_display("loc list                 - List all available area IDs and names")
	_add_to_display("health [value]           - Quick alias: set health")
	_add_to_display("stamina [value]          - Quick alias: set stamina")
	_add_to_display("reset player             - Restore all stats and body condition")
	_add_to_display("reset inv                - Clear inventory and equipment")
	_add_to_display("reset all                - Full reset (stats + inv + time + location)")
	_add_to_display("clear                    - Clear console output")
	_add_to_display("close / exit             - Close the console")


# ------------------------------------------------------------------------------
# Stat setters
# ------------------------------------------------------------------------------

# Validates that value_str is a number before applying it.
func _set_stat(stat: String, value_str: String) -> void:
	if not value_str.is_valid_float():
		_add_to_display("Invalid value: '%s' — must be a number." % value_str)
		return

	var value := maxf(float(value_str), 0.0)

	match stat:
		"health":
			PlayerData.health = minf(value, 100.0)
			_add_to_display("Health set to %.1f" % PlayerData.health)
		"hydration":
			PlayerData.hydration = minf(value, 100.0)
			_add_to_display("Hydration set to %.1f" % PlayerData.hydration)
		"nourishment":
			PlayerData.nourishment = minf(value, 100.0)
			_add_to_display("Nourishment set to %.1f" % PlayerData.nourishment)
		"stamina":
			PlayerData.stamina = minf(value, 100.0)
			_add_to_display("Stamina set to %.1f" % PlayerData.stamina)
		"endurance":
			PlayerData.endurance = minf(value, 100.0)
			_add_to_display("Endurance set to %.1f" % PlayerData.endurance)
		"happiness":
			PlayerData.happiness = minf(value, 100.0)
			_add_to_display("Happiness set to %.1f" % PlayerData.happiness)
		_:
			_add_to_display("Unknown stat: %s" % stat)
			_add_to_display("Available: health, hydration, nourishment, stamina, endurance, happiness")
			return

	PlayerData.notify_stats_changed()


# Adds (or subtracts with a negative value) from a stat.
func _add_stat(stat: String, value_str: String) -> void:
	if not value_str.is_valid_float():
		_add_to_display("Invalid value: '%s' — must be a number." % value_str)
		return

	var value := float(value_str)

	match stat:
		"health":
			PlayerData.health = clampf(PlayerData.health + value, 0.0, 100.0)
			_add_to_display("Health changed by %.1f (now: %.1f)" % [value, PlayerData.health])
		"hydration":
			PlayerData.hydration = clampf(PlayerData.hydration + value, 0.0, 100.0)
			_add_to_display("Hydration changed by %.1f (now: %.1f)" % [value, PlayerData.hydration])
		"nourishment":
			PlayerData.nourishment = clampf(PlayerData.nourishment + value, 0.0, 100.0)
			_add_to_display("Nourishment changed by %.1f (now: %.1f)" % [value, PlayerData.nourishment])
		"stamina":
			PlayerData.stamina = clampf(PlayerData.stamina + value, 0.0, 100.0)
			_add_to_display("Stamina changed by %.1f (now: %.1f)" % [value, PlayerData.stamina])
		"endurance":
			PlayerData.endurance = clampf(PlayerData.endurance + value, 0.0, 100.0)
			_add_to_display("Endurance changed by %.1f (now: %.1f)" % [value, PlayerData.endurance])
		"happiness":
			PlayerData.happiness = clampf(PlayerData.happiness + value, 0.0, 100.0)
			_add_to_display("Happiness changed by %.1f (now: %.1f)" % [value, PlayerData.happiness])
		_:
			_add_to_display("Unknown stat: %s" % stat)
			return

	PlayerData.notify_stats_changed()


# ------------------------------------------------------------------------------
# Time commands
# ------------------------------------------------------------------------------

# Adds hours and minutes to the current in-game clock.
func _add_time(parts: Array[String]) -> void:
	if parts.size() >= 3:
		var h := int(parts[1])
		var m := int(parts[2])
		PlayerData.add_time(h, m)
		_add_to_display("Added %dh %dm — now Day %d %02d:%02d" % [h, m, PlayerData.days, PlayerData.hours, PlayerData.minutes])
	else:
		_add_to_display("Usage: time [hours] [minutes]")


# Overwrites the clock directly without triggering passive effects.
func _set_time(parts: Array[String]) -> void:
	if parts.size() >= 4:
		PlayerData.hours   = int(parts[2])
		PlayerData.minutes = int(parts[3])
		if parts.size() >= 5:
			PlayerData.days = int(parts[4])
		PlayerData.notify_stats_changed()
		_add_to_display("Time set to Day %d, %02d:%02d" % [PlayerData.days, PlayerData.hours, PlayerData.minutes])
	else:
		_add_to_display("Usage: time set [hours] [minutes] [days]")


# ------------------------------------------------------------------------------
# Inventory commands
# ------------------------------------------------------------------------------

# Adds [count] copies of item [id] directly into the player's inventory.
# Uses StaticData.get_item() — the same lookup path used everywhere else.
func _inv_add(parts: Array[String]) -> void:
	if parts.size() < 3:
		_add_to_display("Usage: inv add [id] [count]")
		return

	var item_id := int(parts[2])
	var count   := int(parts[3]) if parts.size() >= 4 else 1

	# Validate the ID exists in StaticData before touching PlayerData.
	var item = StaticData.get_item(item_id)
	if item == null:
		_add_to_display("Item ID %d not found in StaticData." % item_id)
		return

	for _i in count:
		PlayerData.add_to_inventory(item)

	_add_to_display("Added %dx %s (ID %d)" % [count, item["Item Name"], item_id])


# Removes up to [count] copies of item [id] from the player's inventory.
func _inv_remove(parts: Array[String]) -> void:
	if parts.size() < 3:
		_add_to_display("Usage: inv remove [id] [count]")
		return

	var item_id := int(parts[2])
	var count   := int(parts[3]) if parts.size() >= 4 else 1

	for i in count:
		if not PlayerData.remove_from_inventory(item_id):
			_add_to_display("Only removed %d/%d — item ID %d ran out." % [i, count, item_id])
			return

	_add_to_display("Removed %dx item ID %d" % [count, item_id])


# ------------------------------------------------------------------------------
# Equipment commands
# ------------------------------------------------------------------------------

# Looks up the item and places it in the named slot via PlayerData.
func _equip_item(slot: String, item_id_str: String) -> void:
	var item_id := int(item_id_str)
	var item    = StaticData.get_item(item_id)

	if item == null:
		_add_to_display("Item ID %d not found in StaticData." % item_id)
		return

	# PlayerData.set_equipment already warns if the slot name is invalid.
	PlayerData.set_equipment(slot, item)
	_add_to_display("Equipped %s in slot '%s'" % [item["Item Name"], slot])


# Clears whatever is in the named slot.
func _unequip_item(slot: String) -> void:
	PlayerData.clear_equipment(slot)
	_add_to_display("Unequipped slot: %s" % slot)


# ------------------------------------------------------------------------------
# Location commands
# ------------------------------------------------------------------------------

# Lists every area ID and name from StaticData.areaData.
# FIX: StaticData is a Node, not a Dictionary — .has() does not exist on it.
#      Access StaticData.areaData (a Dictionary) directly instead.
func _list_locations() -> void:
	if StaticData.areaData.is_empty():
		_add_to_display("areaData is empty or not yet loaded.")
		return

	_add_to_display("=== Available Locations ===")
	for id in StaticData.areaData:
		var loc: Dictionary = StaticData.areaData[id]
		_add_to_display("ID: %s — %s" % [id, loc.get("Area Name", "Unknown")])


# Teleports the player to the area matching the given string ID (e.g. "3").
func _set_location(loc_id: String) -> void:
	# FIX: was checking StaticData.has("areaData") which crashes because
	#      StaticData is a Node, not a Dictionary. Check areaData directly.
	if not StaticData.areaData.has(loc_id):
		_add_to_display("Location ID '%s' not found. Use 'loc list' to see valid IDs." % loc_id)
		return

	PlayerData.current_location = StaticData.areaData[loc_id]
	PlayerData.notify_stats_changed()
	_add_to_display("Location set to: %s" % PlayerData.current_location.get("Area Name", "Unknown"))


# ------------------------------------------------------------------------------
# Reset commands
# ------------------------------------------------------------------------------

# Restores all vital stats to 100 and every body part to "Healthy".
func _reset_player() -> void:
	PlayerData.health      = 100.0
	PlayerData.hydration   = 100.0
	PlayerData.nourishment = 100.0
	PlayerData.stamina     = 100.0
	PlayerData.endurance   = 100.0
	PlayerData.happiness   = 100.0

	for part in PlayerData.body_condition.keys():
		PlayerData.body_condition[part] = "Healthy"

	PlayerData.notify_stats_changed()
	_add_to_display("Player stats and body condition reset to defaults.")


# Clears all inventory stacks and empties every equipment slot.
func _reset_inventory() -> void:
	# Emit item_removed for every existing stack so the UI cleans up.
	for item_id in PlayerData.inventory.keys():
		PlayerData.item_removed.emit(item_id)

	PlayerData.inventory.clear()

	for slot in PlayerData.equipment.keys():
		PlayerData.equipment[slot] = null

	PlayerData.notify_stats_changed()
	_add_to_display("Inventory and equipment cleared.")


# Full reset: time, location, stats, inventory — then immediately saves.
func _reset_all() -> void:
	PlayerData.days    = 1
	PlayerData.hours   = 6
	PlayerData.minutes = 0

	PlayerData.adventure_steps = 0

	# Return to Home (area ID "1").
	if StaticData.areaData.has("1"):
		PlayerData.current_location = StaticData.areaData["1"]
	else:
		PlayerData.current_location = {}

	_reset_player()
	_reset_inventory()

	PlayerData.save_game()

	_add_to_display("=== COMPLETE RESET PERFORMED ===")
	_add_to_display("Time: Day %d, %02d:%02d" % [PlayerData.days, PlayerData.hours, PlayerData.minutes])
	_add_to_display("Location: %s" % PlayerData.current_location.get("Area Name", "Home"))
	_add_to_display("All stats, inventory, equipment and body condition reset.")
