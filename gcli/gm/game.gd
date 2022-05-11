# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, January 2022

extends Node3D

signal captured_mouse_motion(event)
signal interactive_mouse_motion(event)
signal interactive_mouse_event(event)

var scene_loader: GameSceneLoader

func _init():
	scene_loader = preload("res://gm/game_scene_loader.gd").new()
	add_child(scene_loader)

# Called when the node enters the scene tree for the first time.
#func _ready():

func begin(player_hero_uid: int, map_data: PackedByteArray) -> void:
	$Player/PlayerHero.hero_uid = player_hero_uid
	scene_loader.temp_map_data = map_data
	scene_loader.begin_async($Player/PlayerHero, $World, $Units)

func _process(_delta):
	pass
	# Hacky response to signals not working on child script or something. It's stupid and shouldn't
	# be this way. Moan about it later
#	match result:
#		1:
#			emit_signal("interactive_mouse_event", event)
#		2:
#			emit_signal("captured_mouse_motion", event)
#		3:
#			emit_signal("interactive_mouse_motion", event)
#		_:
#			pass
	
#	print($DirectionalLight3D.rotation.x)
#	if $DirectionalLight3D.rotation.x < PI:
#		$DirectionalLight3D.rotation.x = wrapf($DirectionalLight3D.rotation.x + _delta * 0.2, \
#			0.0, PI * 2.0)
#		$DirectionalLight3D.light_energy = 0.0
#		$WorldEnvironment.environment.background_energy = 0.12
#	else:
#		$DirectionalLight3D.rotation.x = wrapf($DirectionalLight3D.rotation.x + _delta * 0.022, \
#			0.0, PI * 2.0)
#		$DirectionalLight3D.light_energy = 1.0
#		$WorldEnvironment.environment.background_energy = 0.8
	
#the characters capabilities isn't represented by its equipment and its consumables. 
#
#The characters capabilities are represented by its house and accessible services
#
#grind to have consumables for threshold fight which upgrades its house,
# making it more capable of grinding...

func _input(event):
	$Player.register_input_event(event)
