extends Control

@onready var locationLabel = get_node("/root/Node2D/Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Location")
@onready var zombie_amountLabel = get_node("/root/Node2D/Gameplay/Adventure_tscn/MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer/Label2")
@onready var loot_amountLabel = get_node("/root/Node2D/Gameplay/Adventure_tscn/MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer2/Label2")
@onready var distanceLabel = get_node("/root/Node2D/Gameplay/Adventure_tscn/MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer3/Label2")
@onready var current_location = StaticData.areaData["1"]
@export var zombie_amount = 0
@export var loot_amount = 0
@export var adventure_steps = 0
@export var found_loot = []

# Called when the node enters the scene tree for the first time.
func _ready():
	#update_location()
	locationLabel.text = current_location["Area Name"]
	print("moved to ", current_location["Area Name"])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func pick_random_location(areaData):
	var total_weight = 0.0
	var weight
	for area in areaData.values():
		# Adjust weight based on rarity (higher rarity, lower weight)
		weight = area["Rarity"]
		total_weight += weight
	
	var random_pick = randf() * total_weight

	var accumulated_weight = 0.0
	for area in areaData.values():
		accumulated_weight += area["Rarity"]
		if accumulated_weight >= random_pick:
			return area

func pick_random_loot(itemData):
	var loot_table = current_location["Loot Table"]
	
	# Return empty list if no loot
	if loot_amount == 0:
		print("No loot found")
		return []
	
	# Collect item rarities for loot table
	var possible_items = []
	var all_items = itemData.values()
	for itemID in loot_table:
		#var item_id = itemID
		for item in all_items:
			if item["ID"] == itemID:  # Check for key and value
				possible_items.append({
				"ID" : item["ID"],
				"Item Name" : item["Item Name"],
				"Loot Category" : item["Loot Category"],
				"Rarity" : item["Rarity"],
				"Weight" : item["Weight"],
				"Capacity" : item["Capacity"],
				"Durability" : item["Durability"],
		})
	
	# Pick loot according to rarity
	var loot = []
	for i in randi() % (int(loot_amount)+1): # For random amount within range of max amount, use "for i in randi() % (int(loot_amount)+1)"
		var total_weight = 0
		for item in possible_items:
			total_weight += item["Rarity"]
		var random_pick = randf() * total_weight
		var accumulated_weight = 0
		for item in possible_items:
			accumulated_weight += item["Rarity"]
			if random_pick < accumulated_weight:
				loot.append(item)  # Append itemID to loot
				break
	return loot


func _on_next_area_pressed():
	var new_area = pick_random_location(StaticData.areaData)
	get_node("/root/Node2D").minutes += 30
	adventure_steps = adventure_steps + 1
	current_location = new_area
	update_location()

func update_location():
	locationLabel.text = current_location["Area Name"]
	zombie_amount = randi_range(current_location["Zombies Min"],current_location["Zombies Max"])
	loot_amount = current_location["Loot Amount"]
	zombie_amountLabel.text = str(zombie_amount)
	loot_amountLabel.text = str(loot_amount)
	distanceLabel.text = str(adventure_steps*100)+"m"
	if current_location["Loot Amount"] != 0:
		$"MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/Loot area".disabled = false
	print("location updated: " + current_location["Area Name"])

func _on_loot_area_pressed():
	found_loot = pick_random_loot(StaticData.itemData)
	var amount_picked = found_loot.size()
	loot_amount = loot_amount - amount_picked
	loot_amountLabel.text = str(loot_amount)
	for item in found_loot:
		var button = Button.new()
		button.text = str(item["Item Name"])  # Set button text to current item
		get_node("/root/Node2D/Gameplay/Adventure_tscn/Loot_tscn/MarginContainer/PanelContainer/VBoxContainer/MarginContainer/PanelContainer/GridContainer").add_child(button)
	
	if amount_picked != 1:
		get_node("/root/Node2D/Gameplay/Adventure_tscn/Loot_tscn/MarginContainer/PanelContainer/VBoxContainer/MarginContainer2/Label").text = "Your found "+str(amount_picked)+" items"
	else:
		get_node("/root/Node2D/Gameplay/Adventure_tscn/Loot_tscn/MarginContainer/PanelContainer/VBoxContainer/MarginContainer2/Label").text = "Your found "+str(amount_picked)+" item"

	get_node("/root/Node2D/Gameplay/Adventure_tscn/Loot_tscn").visible = true
	
	# Print loot
	var to_print = ""
	for item in found_loot:
		var name = item["Item Name"]
		to_print = to_print + name + ", "
	to_print = to_print.substr(0,to_print.length() -1)
	print("picked loot: ", to_print)
	


func _on_loot_amount_label_draw():
	if loot_amountLabel.text == "0":
		$"MarginContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/Loot area".disabled = true


func _on_loot_tscn_hidden():
	found_loot = []
	print(found_loot)
