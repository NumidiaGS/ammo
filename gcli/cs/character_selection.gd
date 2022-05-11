# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, March 2022
 
extends Node3D

var hero_serialization: Object = preload("res://units/hero_serialization.gd").new()

var auto_delay: float = 0

enum CS_ScreenState {
	NULL = 0,
	Unconnected,
	Connecting,
	DownloadingWorld,
	Authorizing,
	Authorized,
	GameLoading,
}

var screen_state: CS_ScreenState = CS_ScreenState.Unconnected

var authorization_token: String = "null"
var game_scene
var selected_hero_uid: int = 0
var selected_hero_name: String = "null"
var _map_data: Array[PackedByteArray]

# Called when the node enters the scene tree for the first time.
func _ready():
	var args = Array(OS.get_cmdline_args())

	if args.size() != 3:
		# TODO error report or something
		return
		
	var ip: String = args[0] # "68.183.224.36" # 
	var port: int =  args[1].to_int()
	authorization_token = args[2]
	
	auto_delay = 10000
	
	screen_state = CS_ScreenState.Connecting
	var err = Server.begin_game_connection(ip, port, Callable(_begin_connection_callback))
	if err != OK:
		# TODO error report or something
		auto_delay = -10000
		return
	
	$GUI/PlayButton.text = "Connecting"
	$GUI/PlayButton.set('disabled', true)
	

###############################
###### Server Callbacks #######
###############################

func _begin_connection_callback(result: bool):
	if result:
		# Skipping Launcher part atm
		var received_version = 1
		var version = 0 # Set to a high number than received_version to prevent download
		if version < received_version:
			screen_state = CS_ScreenState.DownloadingWorld
			$GUI/PlayButton.text = "DLing World..."
			assert(Server.connect("map_data_received", _on_map_data_received) == OK,\
				"Server::map_data_received")
			Server.temp_get_world_data()
		else:
			_begin_game_server_authorization()
	else:
		$GUI/PlayButton.text = "Connection Error"

func _begin_game_server_authorization() -> void:
	screen_state = CS_ScreenState.Authorizing
	Server.authorise_to_game_server(authorization_token, Callable(_receive_authorization))
	$GUI/PlayButton.text = "Getting Hero..."

func _receive_authorization(result: bool, first_hero_summary: String):
	if result:
		screen_state = CS_ScreenState.Authorized
		# Begin
		# Create the player hero
		var summary = hero_serialization.deserialize_hero_summary(first_hero_summary)
		selected_hero_uid = summary[hero_serialization.SUMMARY_UID]
		selected_hero_name = summary[hero_serialization.SUMMARY_NAME]
		
		$GUI/PlayButton.text = "Playing " + selected_hero_name
		$GUI/PlayButton.set('disabled', false)
		auto_delay = 1.0
	else:
		$GUI/PlayButton.text = "Failed Authorization"

func _on_map_data_received(data: PackedByteArray) -> void:
	_map_data.append(data)
	# TODO -- cache
	# TODO -- at the moment just expecting one data package. In the future... many.
	_begin_game_server_authorization()

###########################
######## Functions ########
###########################

func _load_to_game():
	# Download the game world
	if screen_state == CS_ScreenState.Authorized:
		screen_state = CS_ScreenState.GameLoading
		game_scene = load("res://gm/game.tscn").instantiate()
#		game_scene.visible = false
#		get_tree().root.add_child(game_scene)
#		print("_map_data:", _map_data.size())
		game_scene.begin(selected_hero_uid, _map_data[0])
		$GUI/DownloadStatus/DownloadStatusLabel.text = "0%%"
	else: # CS_ScreenState.GameLoading
		var launch_viability_progress = game_scene.scene_loader.get_scene_viability()
		if launch_viability_progress >= 100:
			print("launching game scene...")
			
			var scene_tree: SceneTree = get_tree()
			scene_tree.root.remove_child(self)
			call_deferred("free")
			
			scene_tree.root.add_child(game_scene)
			scene_tree.change_scene_to(game_scene)
		else:
			$GUI/DownloadStatus/DownloadStatusLabel.text = "%d%%" % [launch_viability_progress]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# TODO remove auto_delay - convenience feature
	if screen_state == CS_ScreenState.Authorized or screen_state == CS_ScreenState.GameLoading:
		auto_delay -= delta
		if auto_delay <= 0.0:
			_load_to_game()

func _on_play_button_pressed():
	_load_to_game()
