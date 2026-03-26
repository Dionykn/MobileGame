extends Control

# ==============================================================================
# DebugConsole — In-game command line for adjusting PlayerData values
# ==============================================================================

@onready var line_edit: LineEdit = $Panel/VBoxContainer/LineEdit
@onready var history_label: Label = $Panel/VBoxContainer/ScrollContainer/MarginContainer/HistoryLabel
@onready var scroll_container: ScrollContainer = $Panel/VBoxContainer/ScrollContainer

# Display history (what shows in the console)
var display_history: Array[String] = []
# Input history (only user commands, for arrow navigation)
var input_history: Array[String] = []
var history_index: int = -1
var is_visible: bool = false

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

func _add_to_display(text: String) -> void:
	display_history.append(text)
	# Keep only last 50 lines
	if display_history.size() > 50:
		display_history.pop_front()
	_update_display()

func _update_display() -> void:
	history_label.text = ""
	for line in display_history:
		history_label.text += line + "\n"
	# Scroll to bottom
	await get_tree().process_frame
	if scroll_container:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _on_line_edit_text_submitted(command: String) -> void:
	if command.is_empty():
		return
	
	# Store the command in input history
	input_history.append(command)
	
	# Show in display with "> " prefix
	_add_to_display("> " + command)
	
	# Process the command
	_process_command(command.strip_edges().to_lower())
	
	# Clear and reset
	line_edit.clear()
	history_index = -1  # Reset history navigation

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				# Navigate up through input history
				if history_index < input_history.size() - 1:
					history_index += 1
					line_edit.text = input_history[input_history.size() - 1 - history_index]
					line_edit.caret_column = line_edit.text.length()
					accept_event()
			KEY_DOWN:
				# Navigate down through input history
				if history_index > 0:
					history_index -= 1
					line_edit.text = input_history[input_history.size() - 1 - history_index]
					line_edit.caret_column = line_edit.text.length()
				elif history_index == 0:
					history_index = -1
					line_edit.text = ""
				accept_event()

func _process_command(command: String) -> void:
	# Convert PackedStringArray to Array[String]
	var parts_packed = command.split(" ", false)
	var parts: Array[String] = []
	for part in parts_packed:
		parts.append(part)
	
	var cmd: String = parts[0] if parts.size() > 0 else ""
	
	match cmd:
		"help":
			_show_help()
		
		"set":
			if parts.size() >= 3:
				_set_stat(parts[1], parts[2])
			else:
				_add_to_display("Usage: set [stat] [value]")
		
		"add":
			if parts.size() >= 3:
				_add_stat(parts[1], parts[2])
			else:
				_add_to_display("Usage: add [stat] [value]")
		
		"time":
			if parts.size() >= 2:
				if parts[1] == "set":
					_set_time(parts)
				else:
					_add_time(parts)
			else:
				_add_to_display("Usage: time [hours] [minutes] OR time set [hours] [minutes] [days]")
		
		"inv":
			if parts.size() >= 3:
				if parts[1] == "add":
					_inv_add(parts)
				elif parts[1] == "remove":
					_inv_remove(parts)
				else:
					_add_to_display("Usage: inv add [id] [count] OR inv remove [id] [count]")
			else:
				_add_to_display("Usage: inv add [id] [count] OR inv remove [id] [count]")
		
		"equip":
			if parts.size() >= 3:
				_equip_item(parts[1], parts[2])
			else:
				_add_to_display("Usage: equip [slot] [item_id]")
		
		"unequip":
			if parts.size() >= 2:
				_unequip_item(parts[1])
			else:
				_add_to_display("Usage: unequip [slot]")
		
		"loc":
			if parts.size() >= 2:
				if parts[1] == "list":
					_list_locations()
				else:
					_set_location(parts[1])
			else:
				_add_to_display("Usage: loc [id] OR loc list")
		
		"reset":
			if parts.size() >= 2:
				match parts[1]:
					"player":
						_reset_player()
					"inv":
						_reset_inventory()
					"all":
						_reset_all()
					_:
						_add_to_display("Usage: reset [player/inv/all]")
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

func _show_help() -> void:
	_add_to_display("=== Debug Console Commands ===")
	_add_to_display("set [stat] [value]     - Set a stat (health, hydration, nourishment, stamina, endurance, happiness)")
	_add_to_display("add [stat] [value]     - Add to a stat (same names as above)")
	_add_to_display("time [h] [m]           - Add hours and minutes")
	_add_to_display("time set [h] [m] [d]   - Set time directly (days optional)")
	_add_to_display("inv add [id] [count]   - Add item by ID (count optional)")
	_add_to_display("inv remove [id] [count]- Remove item by ID")
	_add_to_display("equip [slot] [id]      - Equip item by ID")
	_add_to_display("unequip [slot]         - Unequip item from slot")
	_add_to_display("loc [id]               - Set location by ID")
	_add_to_display("loc list               - List all available locations")
	_add_to_display("health [value]         - Quick health set")
	_add_to_display("stamina [value]        - Quick stamina set")
	_add_to_display("reset player           - Reset all player stats and body condition")
	_add_to_display("reset inv              - Clear all inventory items")
	_add_to_display("reset all              - Reset ALL save data (player stats, inventory, equipment, time, location)")
	_add_to_display("clear                  - Clear console history")
	_add_to_display("close                  - Close console")

func _set_stat(stat: String, value_str: String) -> void:
	var value = float(value_str)
	if value < 0:
		value = 0
	
	match stat:
		"health":
			PlayerData.health = min(value, 100.0)
			_add_to_display("Health set to %.1f" % PlayerData.health)
		"hydration":
			PlayerData.hydration = min(value, 100.0)
			_add_to_display("Hydration set to %.1f" % PlayerData.hydration)
		"nourishment":
			PlayerData.nourishment = min(value, 100.0)
			_add_to_display("Nourishment set to %.1f" % PlayerData.nourishment)
		"stamina":
			PlayerData.stamina = min(value, 100.0)
			_add_to_display("Stamina set to %.1f" % PlayerData.stamina)
		"endurance":
			PlayerData.endurance = min(value, 100.0)
			_add_to_display("Endurance set to %.1f" % PlayerData.endurance)
		"happiness":
			PlayerData.happiness = min(value, 100.0)
			_add_to_display("Happiness set to %.1f" % PlayerData.happiness)
		_:
			_add_to_display("Unknown stat: %s" % stat)
			_add_to_display("Available: health, hydration, nourishment, stamina, endurance, happiness")
	
	PlayerData.notify_stats_changed()

func _add_stat(stat: String, value_str: String) -> void:
	var value = float(value_str)
	
	match stat:
		"health":
			PlayerData.health = min(PlayerData.health + value, 100.0)
			_add_to_display("Health changed by %.1f (now: %.1f)" % [value, PlayerData.health])
		"hydration":
			PlayerData.hydration = min(PlayerData.hydration + value, 100.0)
			_add_to_display("Hydration changed by %.1f (now: %.1f)" % [value, PlayerData.hydration])
		"nourishment":
			PlayerData.nourishment = min(PlayerData.nourishment + value, 100.0)
			_add_to_display("Nourishment changed by %.1f (now: %.1f)" % [value, PlayerData.nourishment])
		"stamina":
			PlayerData.stamina = min(PlayerData.stamina + value, 100.0)
			_add_to_display("Stamina changed by %.1f (now: %.1f)" % [value, PlayerData.stamina])
		"endurance":
			PlayerData.endurance = min(PlayerData.endurance + value, 100.0)
			_add_to_display("Endurance changed by %.1f (now: %.1f)" % [value, PlayerData.endurance])
		"happiness":
			PlayerData.happiness = min(PlayerData.happiness + value, 100.0)
			_add_to_display("Happiness changed by %.1f (now: %.1f)" % [value, PlayerData.happiness])
		_:
			_add_to_display("Unknown stat: %s" % stat)
	
	PlayerData.notify_stats_changed()

func _add_time(parts: Array[String]) -> void:
	if parts.size() >= 3:
		var hours = int(parts[1])
		var minutes = int(parts[2])
		PlayerData.add_time(hours, minutes)
		_add_to_display("Added %d hours, %d minutes" % [hours, minutes])
	else:
		_add_to_display("Usage: time [hours] [minutes]")

func _set_time(parts: Array[String]) -> void:
	if parts.size() >= 4:
		var hours = int(parts[2])
		var minutes = int(parts[3])
		PlayerData.hours = hours
		PlayerData.minutes = minutes
		
		if parts.size() >= 5:
			PlayerData.days = int(parts[4])
		
		PlayerData.notify_stats_changed()
		_add_to_display("Time set to Day %d, %02d:%02d" % [PlayerData.days, PlayerData.hours, PlayerData.minutes])
	else:
		_add_to_display("Usage: time set [hours] [minutes] [days]")

func _inv_add(parts: Array[String]) -> void:
	if parts.size() >= 3:
		var item_id = int(parts[2])
		var count = int(parts[3]) if parts.size() >= 4 else 1
		
		# For now, just show a message. You'll need to implement item retrieval
		_add_to_display("Adding %dx item ID %d (requires item data implementation)" % [count, item_id])
	else:
		_add_to_display("Usage: inv add [id] [count]")

func _inv_remove(parts: Array[String]) -> void:
	if parts.size() >= 3:
		var item_id = int(parts[2])
		var count = int(parts[3]) if parts.size() >= 4 else 1
		
		for i in range(count):
			if not PlayerData.remove_from_inventory(item_id):
				_add_to_display("Failed to remove item ID %d (not enough items)" % item_id)
				return
		
		_add_to_display("Removed %dx item ID %d from inventory" % [count, item_id])
	else:
		_add_to_display("Usage: inv remove [id] [count]")

func _equip_item(slot: String, item_id_str: String) -> void:
	var item_id = int(item_id_str)
	_add_to_display("Equipping item ID %d in slot %s (requires item data implementation)" % [item_id, slot])

func _unequip_item(slot: String) -> void:
	PlayerData.clear_equipment(slot)
	_add_to_display("Unequipped slot: %s" % slot)

func _list_locations() -> void:
	if StaticData.has("areaData"):
		_add_to_display("=== Available Locations ===")
		for id in StaticData.areaData:
			var loc = StaticData.areaData[id]
			_add_to_display("ID: %s - %s" % [id, loc.get("Area Name", "Unknown")])
	else:
		_add_to_display("StaticData.areaData not found or not accessible")

func _set_location(loc_id: String) -> void:
	if StaticData.has("areaData") and StaticData.areaData.has(loc_id):
		PlayerData.current_location = StaticData.areaData[loc_id]
		PlayerData.notify_stats_changed()
		_add_to_display("Location set to: %s" % PlayerData.current_location.get("Area Name", "Unknown"))
	else:
		_add_to_display("Location ID %s not found" % loc_id)

# ==============================================================================
# Reset Functions
# ==============================================================================

func _reset_player() -> void:
	# Reset vital stats to full
	PlayerData.health = 100.0
	PlayerData.hydration = 100.0
	PlayerData.nourishment = 100.0
	PlayerData.stamina = 100.0
	PlayerData.endurance = 100.0
	PlayerData.happiness = 100.0
	
	# Reset body condition to Healthy for all parts
	var body_parts = ["head", "abdomen", "left_arm", "left_hand", "left_leg", "right_arm", "right_hand", "right_leg"]
	for part in body_parts:
		PlayerData.body_condition[part] = "Healthy"
	
	PlayerData.notify_stats_changed()
	_add_to_display("Player stats and body condition reset to default values")

func _reset_inventory() -> void:
	# Emit item_removed for all existing items BEFORE clearing
	for item_id in PlayerData.inventory.keys():
		PlayerData.item_removed.emit(item_id)
	
	# Clear all items from inventory
	PlayerData.inventory.clear()
	
	# Clear all equipment slots
	var equipment_slots = ["hat", "top", "pants", "shoes", "gloves", "backpack", "sling", "waist"]
	for slot in equipment_slots:
		PlayerData.equipment[slot] = null
	
	# Emit signals to update UI
	PlayerData.notify_stats_changed()
	
	_add_to_display("Inventory and equipment cleared")

func _reset_all() -> void:
	# Reset time
	PlayerData.days = 1
	PlayerData.hours = 6
	PlayerData.minutes = 0
	
	# Reset adventure state
	PlayerData.adventure_steps = 0
	
	# Reset location to default (Home)
	if StaticData.has("areaData") and StaticData.areaData.has("1"):
		PlayerData.current_location = StaticData.areaData["1"]
	else:
		PlayerData.current_location = {}
	
	# Reset player stats and body condition
	_reset_player()
	
	# Reset inventory and equipment
	_reset_inventory()
	
	# Force a save to persist the reset
	PlayerData.save_game()
	
	_add_to_display("=== COMPLETE RESET PERFORMED ===")
	_add_to_display("Time: Day %d, %02d:%02d" % [PlayerData.days, PlayerData.hours, PlayerData.minutes])
	_add_to_display("Location: %s" % PlayerData.current_location.get("Area Name", "Home"))
	_add_to_display("All stats, inventory, equipment, and body condition reset")
