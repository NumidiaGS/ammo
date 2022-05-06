extends Node3D

var hero_uid: int
var hero_name: String

var previous_server_time: int
var previous_server_position: Vector3
var previous_server_yaw: float
var recent_server_time: int
var recent_server_position: Vector3
var recent_server_yaw: float

#signal clicked(node: Node, position: Vector3)
signal clicked(node, position)

func _on_body_input_event(_camera, event, location, _normal, _shape_idx):
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
		emit_signal("clicked", self, location)
