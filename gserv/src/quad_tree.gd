# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, April 2022

extends Object

class_name QuadTree

var back_left
var back_right
var front_left
var front_right

var division: Vector2

func init():
	back_left = []
	back_right = []
	front_left = []
	front_right = []

func add_item(item, location: Vector2) -> void:
	if location.x < division.x:
		if location.y < division.y:
			if back_left is Array:
				back_left.append(item)
			else:
				(back_left as QuadTree).add_item(item, location)
		else:
			if front_left is Array:
				front_left.append(item)
			else:
				(front_left as QuadTree).add_item(item, location)
		return
		
	if location.y < division.y:
		if back_right is Array:
			back_right.append(item)
		else:
			(back_right as QuadTree).add_item(item, location)
		return
		
	if front_right is Array:
		front_right.append(item)
	else:
		(front_right as QuadTree).add_item(item, location)
