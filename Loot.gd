extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	for child in $MarginContainer/PanelContainer/VBoxContainer/MarginContainer/PanelContainer/GridContainer.get_children():
		$MarginContainer/PanelContainer/VBoxContainer/MarginContainer/PanelContainer/GridContainer.remove_child(child)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_take_all_pressed():
	pass # Replace with function body.


func _on_leave_pressed():
	get_node("/root/Node2D/Gameplay/Adventure_tscn/Loot_tscn").visible = false
	for child in $MarginContainer/PanelContainer/VBoxContainer/MarginContainer/PanelContainer/GridContainer.get_children():
		$MarginContainer/PanelContainer/VBoxContainer/MarginContainer/PanelContainer/GridContainer.remove_child(child)
