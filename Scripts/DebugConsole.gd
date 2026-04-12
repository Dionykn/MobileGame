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

var display_history: Array[String] = []
var input_history:   Array[String] = []
var history_index:   int  = -1
var is_visible:      bool = false

const BODY_PARTS: Array = [
	"head", "abdomen", "left_arm", "left_hand", "left_leg",
	"right_arm", "right_hand", "right_leg"
]

const BODY_CONDITIONS: Array = ["Healthy", "Hurt", "Healed", "Bleeding"]

# Valid equipment slot names (must match PlayerData.equipment keys exactly).
const EQUIP_SLOTS: Array = [
	"Hat", "Top", "Pants", "Shoes", "Gloves",
	"Backpack", "Sling", "Left hand", "Right hand"
]


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
	if display_history.size() > 50:
		display_history.pop_front()
	_update_display()


func _update_display() -> void:
	history_label.text = ""
	for line in display_history:
		history_label.text += line + "\n"
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
				if history_index < input_history.size() - 1:
					history_index += 1
					line_edit.text = input_history[input_history.size() - 1 - history_index]
					line_edit.caret_column = line_edit.text.length()
					accept_event()
			KEY_DOWN:
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
	var parts_packed := command.split(" ", false)
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
				_add_to_display("Usage: time [hours] [minutes]  OR  time set [hours] [minutes] [days]")

		"inv":
			if parts.size() >= 3:
				if parts[1] == "add":
					_inv_add(parts)
				elif parts[1] == "remove":
					_inv_remove(parts)
				elif parts[1] == "list":
					_inv_list()
				else:
					_add_to_display("Usage: inv add [item_id] [count]  |  inv remove [instance_id]  |  inv list")
			elif parts.size() == 2 and parts[1] == "list":
				_inv_list()
			else:
				_add_to_display("Usage: inv add [item_id] [count]  |  inv remove [instance_id]  |  inv list")

		"equip":
			if parts.size() >= 3:
				_equip_item(parts[1], parts.slice(2))
			else:
				_add_to_display("Usage: equip [instance_id] [slot]")

		"unequip":
			if parts.size() >= 2:
				_unequip_item(parts.slice(1))
			else:
				_add_to_display("Usage: unequip [slot]")

		"loc":
			if parts.size() >= 2:
				if parts[1] == "list":
					_list_locations()
				else:
					_set_location(parts[1])
			else:
				_add_to_display("Usage: loc [id]  OR  loc list")

		"body":
			if parts.size() >= 2:
				if parts[1] == "list":
					_list_body_condition()
				elif parts[1] == "all" and parts.size() >= 3:
					_set_all_body_condition(parts[2])
				elif parts.size() >= 3:
					_set_body_condition(parts[1], parts[2])
				else:
					_add_to_display("Usage: body [part] [condition]  OR  body all [condition]  OR  body list")
			else:
				_add_to_display("Usage: body [part] [condition]  OR  body all [condition]  OR  body list")

		"reset":
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
	_add_to_display("set [stat] [value]              - Set a stat to an exact value")
	_add_to_display("add [stat] [value]              - Add/subtract from a stat")
	_add_to_display("  Stats: health, hydration, nourishment, stamina, endurance, happiness")
	_add_to_display("time [h] [m]                    - Add hours/minutes to current time")
	_add_to_display("time set [h] [m] [d]            - Set time directly (days optional)")
	_add_to_display("inv add [item_id] [count]       - Add item by static ID (count defaults to 1)")
	_add_to_display("inv remove [instance_id]        - Remove one from an inventory instance")
	_add_to_display("inv list                        - Show all inventory instances with IDs")
	_add_to_display("equip [instance_id] [slot]      - Equip an inventory instance into a slot")
	_add_to_display("unequip [slot]                  - Unequip and return item to inventory")
	_add_to_display("  Slots: Hat, Top, Pants, Shoes, Gloves, Backpack, Sling,")
	_add_to_display("         Left hand, Right hand")
	_add_to_display("body [part] [condition]         - Set one body part condition")
	_add_to_display("body all [condition]            - Set all body parts")
	_add_to_display("body list                       - Show all body part conditions")
	_add_to_display("  Parts: head, abdomen, left_arm, left_hand, left_leg,")
	_add_to_display("         right_arm, right_hand, right_leg")
	_add_to_display("  Conditions: Healthy, Hurt, Healed, Bleeding")
	_add_to_display("loc [id]                        - Teleport to area by ID")
	_add_to_display("loc list                        - List all area IDs and names")
	_add_to_display("health [value]                  - Quick alias: set health")
	_add_to_display("stamina [value]                 - Quick alias: set stamina")
	_add_to_display("reset player                    - Restore all stats and body condition")
	_add_to_display("reset inv                       - Clear inventory and equipment")
	_add_to_display("reset all                       - Full reset")
	_add_to_display("clear                           - Clear console output")
	_add_to_display("close / exit                    - Close the console")


# ------------------------------------------------------------------------------
# Stat setters
# ------------------------------------------------------------------------------

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


func _add_stat(stat: String, value_str: String) -> void:
	if not value_str.is_valid_float():
		_add_to_display("Invalid value: '%s' — must be a number." % value_str)
		return
	var value := float(value_str)
	match stat:
		"health":
			PlayerData.health = clampf(PlayerData.health + value, 0.0, 100.0)
			_add_to_display("Health → %.1f" % PlayerData.health)
		"hydration":
			PlayerData.hydration = clampf(PlayerData.hydration + value, 0.0, 100.0)
			_add_to_display("Hydration → %.1f" % PlayerData.hydration)
		"nourishment":
			PlayerData.nourishment = clampf(PlayerData.nourishment + value, 0.0, 100.0)
			_add_to_display("Nourishment → %.1f" % PlayerData.nourishment)
		"stamina":
			PlayerData.stamina = clampf(PlayerData.stamina + value, 0.0, 100.0)
			_add_to_display("Stamina → %.1f" % PlayerData.stamina)
		"endurance":
			PlayerData.endurance = clampf(PlayerData.endurance + value, 0.0, 100.0)
			_add_to_display("Endurance → %.1f" % PlayerData.endurance)
		"happiness":
			PlayerData.happiness = clampf(PlayerData.happiness + value, 0.0, 100.0)
			_add_to_display("Happiness → %.1f" % PlayerData.happiness)
		_:
			_add_to_display("Unknown stat: %s" % stat)
			return
	PlayerData.notify_stats_changed()


# ------------------------------------------------------------------------------
# Time commands
# ------------------------------------------------------------------------------

func _add_time(parts: Array[String]) -> void:
	if parts.size() >= 3:
		var h := int(parts[1])
		var m := int(parts[2])
		PlayerData.add_time(h, m)
		_add_to_display("Added %dh %dm — now Day %d %02d:%02d" % [h, m, PlayerData.days, PlayerData.hours, PlayerData.minutes])
	else:
		_add_to_display("Usage: time [hours] [minutes]")


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

func _inv_add(parts: Array[String]) -> void:
	if parts.size() < 3:
		_add_to_display("Usage: inv add [item_id] [count]")
		return
	var item_id := int(parts[2])
	var count   := int(parts[3]) if parts.size() >= 4 else 1
	var item    = StaticData.get_item(item_id)
	if item == null:
		_add_to_display("Item ID %d not found in StaticData." % item_id)
		return
	for _i in count:
		PlayerData.add_to_inventory(item)
	_add_to_display("Added %dx %s (item ID %d)" % [count, item["Item Name"], item_id])


func _inv_remove(parts: Array[String]) -> void:
	if parts.size() < 3:
		_add_to_display("Usage: inv remove [instance_id]")
		return
	var instance_id := int(parts[2])
	if not PlayerData.remove_from_inventory(instance_id):
		_add_to_display("Instance ID %d not found in inventory." % instance_id)
	else:
		_add_to_display("Removed one from instance ID %d." % instance_id)


func _inv_list() -> void:
	if PlayerData.inventory.is_empty():
		_add_to_display("Inventory is empty.")
		return
	_add_to_display("=== Inventory ===")
	for instance in PlayerData.inventory:
		var opened_tag := " [opened]" if instance["opened"] else ""
		_add_to_display("  [%d] %s  x%d%s" % [
			instance["instance_id"],
			instance["item"]["Item Name"],
			instance["count"],
			opened_tag,
		])


# ------------------------------------------------------------------------------
# Equipment commands
# ------------------------------------------------------------------------------

func _equip_item(instance_id_str: String, slot_parts: Array[String]) -> void:
	var instance_id := int(instance_id_str)
	var slot_words: Array[String] = []
	for i in slot_parts.size():
		var word: String = slot_parts[i]
		slot_words.append(word.substr(0, 1).to_upper() + word.substr(1))
	var slot := " ".join(slot_words)

	var instance = PlayerData.get_instance(instance_id)
	if instance == null:
		_add_to_display("Instance ID %d not found. Use 'inv list' to see valid IDs." % instance_id)
		return

	if PlayerData.equip_item(instance_id, slot):
		_add_to_display("Equipped '%s' in slot '%s'." % [instance["item"]["Item Name"], slot])
	else:
		_add_to_display("Could not equip instance %d in slot '%s'." % [instance_id, slot])


func _unequip_item(slot_parts: Array[String]) -> void:
	var slot_words: Array[String] = []
	for word in slot_parts:
		slot_words.append(word.substr(0, 1).to_upper() + word.substr(1))
	var slot := " ".join(slot_words)

	if PlayerData.unequip_slot(slot):
		_add_to_display("Unequipped slot: %s" % slot)
	else:
		_add_to_display("Slot '%s' is already empty or does not exist." % slot)


# ------------------------------------------------------------------------------
# Body condition commands
# ------------------------------------------------------------------------------

func _normalise_condition(raw: String) -> String:
	match raw:
		"healthy":  return "Healthy"
		"hurt":     return "Hurt"
		"healed":   return "Healed"
		"bleeding": return "Bleeding"
		_:          return ""


func _list_body_condition() -> void:
	_add_to_display("=== Body Condition ===")
	for part in BODY_PARTS:
		_add_to_display("  %s: %s" % [part, PlayerData.body_condition.get(part, "Healthy")])


func _set_body_condition(part_raw: String, condition_raw: String) -> void:
	if not BODY_PARTS.has(part_raw):
		_add_to_display("Unknown body part: '%s'" % part_raw)
		_add_to_display("Valid parts: %s" % ", ".join(BODY_PARTS))
		return
	var condition: String = _normalise_condition(condition_raw)
	if condition.is_empty():
		_add_to_display("Unknown condition: '%s'. Valid: Healthy, Hurt, Healed, Bleeding" % condition_raw)
		return
	PlayerData.body_condition[part_raw] = condition
	PlayerData.notify_stats_changed()
	_add_to_display("Body condition set — %s: %s" % [part_raw, condition])


func _set_all_body_condition(condition_raw: String) -> void:
	var condition: String = _normalise_condition(condition_raw)
	if condition.is_empty():
		_add_to_display("Unknown condition: '%s'. Valid: Healthy, Hurt, Healed, Bleeding" % condition_raw)
		return
	for part in BODY_PARTS:
		PlayerData.body_condition[part] = condition
	PlayerData.notify_stats_changed()
	_add_to_display("All body parts set to: %s" % condition)


# ------------------------------------------------------------------------------
# Location commands
# ------------------------------------------------------------------------------

func _list_locations() -> void:
	if StaticData.areaData.is_empty():
		_add_to_display("areaData is empty.")
		return
	_add_to_display("=== Available Locations ===")
	for id in StaticData.areaData:
		_add_to_display("ID: %s — %s" % [id, StaticData.areaData[id].get("Area Name", "Unknown")])


func _set_location(loc_id: String) -> void:
	var area = StaticData.get_area(int(loc_id))
	if area == null:
		_add_to_display("Location ID '%s' not found. Use 'loc list'." % loc_id)
		return
	PlayerData.current_location = area
	PlayerData.notify_stats_changed()
	_add_to_display("Location set to: %s" % PlayerData.current_location.get("Area Name", "Unknown"))


# ------------------------------------------------------------------------------
# Reset commands
# ------------------------------------------------------------------------------

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
	_add_to_display("Player stats and body condition reset.")


func _reset_inventory() -> void:
	for instance in PlayerData.inventory.duplicate():
		PlayerData.item_removed.emit(instance["instance_id"])
	PlayerData.inventory.clear()
	for slot in PlayerData.equipment.keys():
		PlayerData.equipment[slot] = null
	PlayerData.notify_stats_changed()
	_add_to_display("Inventory and equipment cleared.")


func _reset_all() -> void:
	PlayerData.days    = 1
	PlayerData.hours   = 6
	PlayerData.minutes = 0
	PlayerData.adventure_steps = 0
	var home = StaticData.get_area(1)
	PlayerData.current_location = home if home != null else {}
	_reset_player()
	_reset_inventory()
	PlayerData.save_game()
	_add_to_display("=== COMPLETE RESET ===")
	_add_to_display("Day %d, %02d:%02d — %s" % [
		PlayerData.days, PlayerData.hours, PlayerData.minutes,
		PlayerData.current_location.get("Area Name", "Home")
	])
