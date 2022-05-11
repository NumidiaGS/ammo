# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, January 2022

extends MeshInstance3D

var bounce_up: bool = false
var bounce_duration: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.

func _process(delta):
	bounce_duration += delta
	if bounce_duration > 1.2:
		bounce_duration = 0.0
		bounce_up = not bounce_up
	if bounce_up:
		position.y -= delta * 0.5
	else:
		position.y += delta * 0.5
