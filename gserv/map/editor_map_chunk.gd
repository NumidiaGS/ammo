# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, April 2022

extends Node3D

class_name EditorMapChunk

# Permitted Values both integers signed 16 ( Range: -32768 to +32767)
@export var location: Vector2i

@export_file("*.png") var height_map: String
