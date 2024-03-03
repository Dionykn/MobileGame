extends Control

@onready var locationLabel = get_node("/root/Node2D/Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Location")
@onready var current_location = StaticData.areaData["1"]
var adventure_steps = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	locationLabel.text = current_location["Area Name"]
	$MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer/Label2.text = "0"
	$MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer2/Label2.text = "0"
	$MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer3/Label2.text = "0m"
	print("sent signal: ", current_location["Area Name"])

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

#func pick_random_loot(areaLoot):
	#var all_loot = StaticData.itemData
	#var area_loot = areaLoot
	#var max_loot = current_location["Loot Amount"]
	#var selected_loot = []
#
	## Build a dictionary to store item_IDs and their weights based on rarity
	#var weighted_loot = {}
	#for item_ID in area_loot:
		#var item_data = all_loot[item_ID]
		#var weight = item_data["Rarity"]  # Adjust weight calculation as needed
		#weighted_loot[item_ID] = weight
#
	## Pick max_loot items using weighted random selection
	#for _i in range(max_loot):
		#var random_pick = randf() * sum(weighted_loot.values())
#
		#for item_ID in weighted_loot.keys():
			#random_pick -= weighted_loot[item_ID]
			#if random_pick <= 0:
				#selected_loot.append(item_ID)
				#break
#
	#return selected_loot
	

func _on_next_area_pressed():
	var selected_area = pick_random_location(StaticData.areaData)
	get_node("/root/Node2D").minutes += 30
	adventure_steps = adventure_steps + 1
	locationLabel.text = selected_area["Area Name"]
	$MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer/Label2.text = str(randi_range(selected_area["Zombies Min"],selected_area["Zombies Max"]))
	$MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer2/Label2.text = str(selected_area["Loot Amount"])
	$MarginContainer/VBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/HBoxContainer3/Label2.text = str(adventure_steps*100)+"m"
	print(selected_area["Area Name"],selected_area["Rarity"])


func _on_loot_area_pressed():
	pass # Replace with function body.
