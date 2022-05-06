extends Camera3D

const MOUSE_SENSITIVITY: float = 0.05
const LOOKAT_DISTANCE_OFFSET: float = 16.0
const LOOKAT_VERTICAL_OFFSET: float = 5.0

@onready var _player_hero: PlayerHero = get_node("/root/Game/Player/PlayerHero")
@onready var _world_node: Node3D = get_node("/root/Game/World")
@onready var _target_label: Label = get_node("/root/Game/GUI/TargetLabel")

var _pitch: float = PI * 11 / 16
var _camera_pitch_offset: Vector2 = Vector2(13.3, 8.9)
var _mouse_y_delta: float = 0
#var _latent_velocity: Vector3 = Vector3.ZERO
var _latent_target: Vector3

var _mouseover_target: MapObject

# Called when the node enters the scene tree for the first time.
func _ready():
	var _game_node: Node3D = get_node("/root/Game")
#	assert(_game_node.connect("captured_mouse_motion", _on_captured_mouse_motion) == OK, \
#		"PlayerHeroFollowCamera connect to Game::captured_mouse_motion")
#	assert(_game_node.connect("interactive_mouse_event", _on_interactive_mouse_event) == OK, \
#		"PlayerHeroFollowCamera connect to Game::interactive_mouse_event")
#	assert(_game_node.connect("interactive_mouse_motion", _on_interactive_mouse_motion) == OK, \
#		"PlayerHeroFollowCamera connect to Game::interactive_mouse_motion")
	_latent_target = _player_hero.position

func adjust_pitch(amount: float) -> void:
	_mouse_y_delta += amount

func _update_mouseover_target(screen_position: Vector2) -> void:
	var ray_dir = project_ray_normal(screen_position)
	_mouseover_target = _world_node.get_picking_collision(position, ray_dir, 8.0)
	if not _mouseover_target:
		_target_label.text = "NoTarget"
	else:
		_target_label.text = str(_mouseover_target.object_uid)

func _on_interactive_mouse_event(event: InputEventMouse) -> void:
	_update_mouseover_target(event.global_position)
	
	if not _mouseover_target:
		return
	
	var button_event: InputEventMouseButton = event
	if button_event and button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
		match _mouseover_target.interaction_behaviour:
			MapObject.InteractionBehaviour.BerryBush:
				Server.interact_with_object(_mouseover_target.object_uid)

func _on_interactive_mouse_motion(event: InputEventMouseMotion) -> void:
	_update_mouseover_target(event.global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if _mouse_y_delta:
		_pitch = clampf(_pitch + delta * _mouse_y_delta * MOUSE_SENSITIVITY, PI * 9 / 16, \
			PI * 15 / 16)
		_mouse_y_delta = 0.0
		_camera_pitch_offset = Vector2.UP.rotated(_pitch) * LOOKAT_DISTANCE_OFFSET
#		print("_camera_pitch_offset:", _camera_pitch_offset)
	
#	var target_diff = _player_hero.position - _latent_target
#	_latent_velocity += target_diff * delta * max(1.0, target_diff.length_squared())
#	_latent_target += target_diff * delta * max(6.0, target_diff.length_squared())
	
	var horizontal_offset: Vector2 = Vector2.UP.rotated(-_player_hero.rotation.y) \
		* _camera_pitch_offset.x
#	var target_offset = _latent_target + Vector3(horizontal_offset.x, _camera_pitch_offset.y, \
#		horizontal_offset.y)
	
#	var difference = target_offset - position
#	position += difference * 1.0
	position = _player_hero.position + Vector3(horizontal_offset.x, _camera_pitch_offset.y, \
		horizontal_offset.y)
#	var jump_deficit: float = max(min(_player_hero.position.y * 0.2, 3), 0)
	look_at(_player_hero.position + Vector3(0, LOOKAT_VERTICAL_OFFSET, 0), Vector3.UP)
