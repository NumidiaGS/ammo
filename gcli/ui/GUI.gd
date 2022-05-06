extends Control

var player_hero: PlayerHero

# Called when the node enters the scene tree for the first time.
func _ready():
	$Inventory.visible = false
	
	player_hero = get_node("/root/Game/Player/PlayerHero")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

#func _unhandled_input(event):
#	print("GUI:", event)



func _on_action_button_pressed(action_title: String):
	match action_title:
		"PlaceProperty":
			print("placeproperty")
			var area: Rect2i = Rect2i(int(player_hero.position.x) - 10, \
				int(player_hero.position.y) - 10, 20, 20)
			Server.create_holding("Farm", area)
		_:
			print("_on_action_button_pressed: Unhandled action press:", action_title)
