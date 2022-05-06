extends Node3D

class_name EditorMapChunk

# Permitted Values both integers signed 16 ( Range: -32768 to +32767)
@export var location: Vector2i

@export_file("*.png") var height_map: String
