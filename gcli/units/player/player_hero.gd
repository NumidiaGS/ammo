extends CharacterBody3D

class_name PlayerHero

signal clicked(node, position)
signal light_pickup_collision(light_node)

#@export var MovementForce: float = 36.0
#@export var GroundFrictionDecay: float = 0.8
#@export var GroundFrictionResidual: float = 6.0
#@export var MaxSpeed: float = 7.0
#@export var Gravity: float = 20.0
#@export var Terminal_Velocity: float = -18.0
#@export var JumpImpulse: float = 13.0
@export var MouseSensitivity: float = 0.1

var mutex: Mutex = Mutex.new()

var _world_node: Node3D
var _state_label: Node
#var _target: Node3D

# Summary
var hero_uid: int
var hero_name: String = "null"

# State
var hitpoints: int
var satiation: float

# Hero Movement Settings
# TODO Keep this Synchronized with server: /gserv/src/world.gd
const HERO_GRAVITY: float = 22.0
const HERO_TERMINAL_VELOCITY: float = HERO_GRAVITY
const HERO_HORIZONTAL_VELOCITY: float = 8.0
const HERO_JUMP_VELOCITY: float = 14.5

# Hero Input Mask Values
# TODO Keep this Synchronized with server: /gserv/src/players/hero_data.gd
const HERO_INPUT_MoveForward: int = 1
const HERO_INPUT_MoveBackward: int = 2
const HERO_INPUT_RotateLeft: int = 4
const HERO_INPUT_RotateRight: int = 8
const HERO_INPUT_StrafeLeft: int = 16
const HERO_INPUT_StrafeRight: int = 32
const HERO_INPUT_Jump: int = 64

const ServerPositionUpdateFrequency: float = 1.0 / 20.0
var time_since_last_input_update: float = 0.0

var _key_w: bool = false
var _key_s: bool = false
var _key_a: bool = false
var _key_d: bool = false
var _key_z: bool = false
var _key_c: bool = false
var _key_space: bool = false
var _mouse_delta_x: float
var _autorun_toggled: bool = false

#var _server_hero_position: Vector3 = Vector3.ZERO
var _server_hero_update_time: float = 0.0
#var _server_hero_yaw: float = 0.0
#var _predicted_server_velocity: Vector3 = Vector3.ZERO
var _is_grounded: bool = false
var _vertical_velocity: float = 0.0
#var _since_server_frame_controls: Array[int] = [0]
#var _since_server_frame_yaw: Array[float] = [0.0]
#var _since_server_frame_time: Array[int] = [0]

#var _time_of_predicted_server_position: int
#var _predicted_server_position: Vector3 = Vector3.ZERO
#var phys_velocity: Vector3
#var phys_grounded: bool

#var tar_pos: Vector3

###############################################################
######################## Initialization #######################
###############################################################

func _ready():
	var _game_node = get_node("/root/Game")
	_world_node = get_node("/root/Game/World")
	
#	network.connect("character_update", self, "_on_websocket_character_spawn")
	assert(Server.connect("hero_state_received", _on_hero_state_received) == OK,\
		"PlayerHero connect to Server::hero_state_received")
	assert(Server.connect("player_hero_death", on_player_hero_death) == OK, \
		"PlayerHero connect to Server::player_hero_death")
	assert(Server.connect("player_hero_placement", on_player_hero_placement) == OK, \
		"PlayerHero connect to Server::player_hero_placement")
	assert(Server.connect("player_hero_position_update", on_player_hero_position_update) == OK, \
		"PlayerHero connect to Server::player_hero_position_update")
		
	_state_label = get_node("/root/Game/GUI/HeroStateLabel")
	
	var vw: Viewport = get_node("/root")
	vw.physics_object_picking = true

###############################################################
###################### Network Callbacks ######################
###############################################################

func _on_hero_state_received(server_light: int, server_hitpoints: int, server_satiation: float):
	hitpoints = server_hitpoints
	satiation = server_satiation
	_state_label.text = "food:%d" % [satiation]

func on_player_hero_death(reason: String, respawn_location: Vector3) -> void:
	print("player died: ", reason)
	on_player_hero_placement(respawn_location, 0)
	pass

func on_player_hero_placement(pos: Vector3, yaw: float) -> void:
	position = pos
	rotation = Vector3(0.0, yaw, 0.0)

func on_player_hero_position_update(server_update_time: int, pos: Vector3, yaw: float, \
	vel: Vector3) -> void:
	# Update the hero player position
	register_server_hero_record(server_update_time, pos, yaw, vel)

###############################################################
###############################################################
###############################################################

func adjust_yaw(amount: float):
	_mouse_delta_x += amount

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _unhandled_key_input(event):
	match event.keycode:
		KEY_W:
			_key_w = event.pressed
		KEY_S:
			_key_s = event.pressed
		KEY_A:
			_key_a = event.pressed
		KEY_D:
			_key_d = event.pressed
		KEY_Z:
			_key_z = event.pressed
		KEY_C:
			_key_c = event.pressed
		KEY_Q:
			_autorun_toggled = !_autorun_toggled
		KEY_SPACE:
			_key_space = event.pressed

func _process(delta):
	_update_hero_control(delta)

func _update_hero_control(delta: float):
	# Mouse Input
	# Yaw
	if _mouse_delta_x != 0:
		var yaw: float = rotation.y
		yaw -= _mouse_delta_x * delta * MouseSensitivity
		rotation.y = wrapf(yaw, -PI, PI)
		
		# Reset Measure
		_mouse_delta_x = 0
	
#	# 'Roll'
#	if _mouse_motion.y != 0:
#		var roll: float = $Head.rotation.x
#		roll = clampf(roll - _mouse_motion.y * delta * MouseSensitivity, -0.45 * PI, 0.45 * PI)
#		$Head.rotation.x = roll
	
	# Keyboard Movement
	var control_input: int = 0
	if _key_w:
#		_autorun_toggled = false
		control_input |= HERO_INPUT_MoveForward
	if _key_s:
		control_input |= HERO_INPUT_MoveBackward
	if _key_a:
		control_input |= HERO_INPUT_StrafeLeft
	if _key_d:
		control_input |= HERO_INPUT_StrafeRight
	if _key_z:
		control_input |= HERO_INPUT_RotateLeft
	if _key_c:
		control_input |= HERO_INPUT_RotateRight
	if _key_space:
		control_input |= HERO_INPUT_Jump
#	print("control_input:", control_input)
	
	# Let input affect current position
	var movement: Vector3 = _process_movement_input(delta, control_input)
	# TODO collisions / slides / etc
	if position.y + movement.y <= 0:
		_is_grounded = true
		movement.y = 0.0
		position.y = 0.0
		_vertical_velocity = 0.0
	position += movement
	
#	# Add to control input buffers
#	var est_server_time = Server.get_current_server_time()
	
	# Send Input Updates to the server
	time_since_last_input_update += delta
	const server_update_period: float = 1.0 / 30.0 # 30 FPS -- TODO const this
	if time_since_last_input_update >= server_update_period:
		# Update the server
		time_since_last_input_update = min(time_since_last_input_update - server_update_period, \
			server_update_period)
		Server.send_hero_control_update(position, _vertical_velocity, rotation.y, control_input)
		
#		_since_server_frame_time.append(est_server_time)
#		_since_server_frame_controls.append(control_input)
#		_since_server_frame_yaw.append(rotation.y)
#
#		_estimate_server_position
	
#	# Continue the current prediction of the server position
#	var since_last_prediction = est_server_time - _time_of_predicted_server_position
#	var frame_movement: Vector3 = Vector3.ZERO
#	if since_last_prediction > 0:
#		frame_movement = _apply_prediction_frame(_since_server_frame_time.size() - 1, \
#			since_last_prediction)
#		_time_of_predicted_server_position = est_server_time
#	elif since_last_prediction < 0:
#		# TODO
##		print("WARNING] est_server_time < _prediction_server_time for PREVIOUS frame")
#		pass
#
#	# Apply Frame Movement and attempt to correct current position
#	position += frame_movement
#	var sc_diff = Vector2(_predicted_server_position.x - position.x, \
#		_predicted_server_position.z - position.z)
#	var sc_len = sc_diff.length()
#	if sc_len < delta * 2.0:
#		position.x = _predicted_server_position.x
#		position.z = _predicted_server_position.z
#	else:
#		var closure_multiplier = delta * (sc_len * sc_len + 0.5 \
#			+ _predicted_server_velocity.length() * 3.0)
#		position.x += sc_diff.x * closure_multiplier
#		position.z += sc_diff.y * closure_multiplier
##	print("sc_len:", sc_len)
#
#	var ydiff = _predicted_server_position.y - position.y
#	if absf(ydiff) < delta * 5.0:
#		position.y = _predicted_server_position.y
##		print("yadd:", ydiff)
#	else:
#		var add = ydiff * delta * (5.0 + absf(ydiff + _predicted_server_velocity.y * 0.5))
#		position.y += add
#
##		print("ydiff:", _predicted_server_position.y - position.y, "  (%f)" % [add])
##	if _predicted_server_position.y >= 0:
##		position.y = (_predicted_server_position.y + position.y) * 0.5
##		 HERO_GRAVITY * delta * (0.0 + (_predicted_server_position.y - position.y) * \
##			(_predicted_server_position.y - position.y))
##
###	print("_predicted_server_velocity:", _predicted_server_velocity)

func _process_movement_input(delta: float, input: int) -> Vector3:
	# Process Input
	var movement: Vector2 = Vector2.ZERO
	if input & HERO_INPUT_MoveForward:
		movement.y = 1.0
	if input & HERO_INPUT_MoveBackward:
		movement.y = -1.0
	if input & HERO_INPUT_StrafeLeft:
		movement.x = 1.0
	if input & HERO_INPUT_StrafeRight:
		movement.x = -1.0
	if position.y <= 0:
		_is_grounded = true
		_vertical_velocity = 0
	if _is_grounded:
		if input & HERO_INPUT_Jump:
			_vertical_velocity = HERO_JUMP_VELOCITY
			_is_grounded = false
	else:
		_vertical_velocity = max(_vertical_velocity - delta * HERO_GRAVITY, -HERO_TERMINAL_VELOCITY)
#		print("_vertical_velocity", _vertical_velocity)

	movement = movement.rotated(-rotation.y).normalized() * HERO_HORIZONTAL_VELOCITY
	return Vector3(movement.x, _vertical_velocity, movement.y) * delta

## Applies the saved frame input buffers to the predicted current server position
#func _apply_prediction_frame(frame_idx: int, delta_msec: int) -> Vector3:
#	var input_mask = _since_server_frame_controls[frame_idx]
#	var yaw = _since_server_frame_yaw[frame_idx]
#	var delta = 0.001 * delta_msec
#
#	# Determine impulse
#	var impulse: Vector2 = Vector2.ZERO
#	if input_mask & HERO_INPUT_MoveForward:
#		impulse.y = 1.0
#	if input_mask & HERO_INPUT_MoveBackward:
#		impulse.y = -1.0
#	if input_mask & HERO_INPUT_StrafeLeft:
#		impulse.x = 1.0
#	if input_mask & HERO_INPUT_StrafeRight:
#		impulse.x = -1.0
#	if _predicted_server_is_grounded and input_mask & HERO_INPUT_Jump:
#		_predicted_server_velocity.y = HERO_JUMP_IMPULSE
#
#	impulse = impulse.rotated(-yaw).normalized() * delta * HERO_IMPULSE
#
#	# Decay previous frames velocity
#	var decay: float = 1.0 - 5.0 * delta
#	_predicted_server_velocity.x *= decay
#	_predicted_server_velocity.z *= decay
#
#	# Apply impulse
#	_predicted_server_velocity.x += impulse.x
#	_predicted_server_velocity.z += impulse.y
#	if !_predicted_server_is_grounded:
#		_predicted_server_velocity.y -= HERO_GRAVITY * delta
#		if _predicted_server_velocity.y < -HERO_TERMINAL_VELOCITY:
#			_predicted_server_velocity.y = -HERO_TERMINAL_VELOCITY
#
#	# Cut off small horizontal velocity
#	if _predicted_server_velocity.x * _predicted_server_velocity.x + _predicted_server_velocity.z \
#		* _predicted_server_velocity.z < 0.005:
#		_predicted_server_velocity.x = 0.0
#		_predicted_server_velocity.z = 0.0
#
#	# Determine any collisions
#	if _predicted_server_position.y + _predicted_server_velocity.y * delta <= 0.0:
#		_predicted_server_is_grounded = true
#		_predicted_server_velocity.y = 0.0
#		_predicted_server_position.y = 0.0
#
#	# Apply velocity
#	var movement = _predicted_server_velocity * delta
#	_predicted_server_position += movement
#	_time_of_predicted_server_position += delta_msec
#
#	return movement


#func _physics_process(delta):
#	_update_movement_physics(delta)
#	var kc: KinematicCollision3D = move_and_collide(motion_velocity * delta, true)
#	if kc:
#		var shape: Node3D = kc.get_collider_shape()
##		print("shape:", shape.get_class())
##		print("s_p:", shape.get_parent())
##		print("s_p:", shape.get_parent().get_parent().name)
#		if shape and shape.get_parent():
#			var iable = shape.get_parent().get_parent()
#			var iable_name: String = iable.name
#			if iable and iable_name.begins_with("LightPickup"):
##				position += kc.get_remainder()
#				emit_signal("light_pickup_collision", iable)
#	move_and_slide()
#
#	_update_server_position()

func _on_body_input_event(_camera, event, location, _normal, _shape_idx):
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
		emit_signal("clicked", self, location)

func register_server_hero_record(server_update_time: int, _server_position: Vector3, \
	_server_yaw: float, _server_velocity: Vector3) -> void:
	if server_update_time <= _server_hero_update_time:
		# Delayed or duplicate UDP packet
		# Ignore it
		return
	# TODO change this method to one that corrects the server hero position when it is wrong
	pass

#	# Remove all intermittant frame records before the new server time
#	var i = 0
#	while i + 1 < _since_server_frame_time.size():
#		if _since_server_frame_time[i + 1] > server_update_time:
#			break
#		i += 1
#	for j in range(0, _since_server_frame_time.size() - i):
#		_since_server_frame_time[j] = _since_server_frame_time[i + j]
#		_since_server_frame_controls[j] = _since_server_frame_controls[i + j]
#		_since_server_frame_yaw[j] = _since_server_frame_yaw[i + j]
#	_since_server_frame_time.resize(_since_server_frame_time.size() - i)
#	_since_server_frame_time[0] = server_update_time
#	_since_server_frame_controls.resize(_since_server_frame_controls.size() - i)
#	_since_server_frame_yaw.resize(_since_server_frame_yaw.size() - i)
	
#	# Temp Set
#	_server_hero_update_time = server_update_time
#	position = server_position
#	velocity = server_velocity
#
#	_predicted_server_is_grounded = server_velocity.y != 0.0
	
	
#	# Set
#	_server_hero_update_time = server_update_time
#	_server_hero_position = server_position
#	_server_hero_yaw = server_yaw
#
#	# TODO
#	_predicted_server_velocity = server_velocity
#	_predicted_server_is_grounded = server_velocity.y == 0
#
#	# Re-initialize server predicted position
#	_predicted_server_position = _server_hero_position
#
#	if _server_hero_update_time > _time_of_predicted_server_position:
#		_time_of_predicted_server_position = server_update_time
#		return
#
#	# Update the current predicted server position from position predicted from the latest
#	#   server update (to the previously predicted server time
#	var _server_time_predicted_to: int = _server_hero_update_time as int
#	var latest_frame_idx: int = _since_server_frame_time.size() - 1
#	for i in range(0, latest_frame_idx):
#		var break_loop = false
#		var prediction_period: int
#		if _since_server_frame_time[i + 1] > _time_of_predicted_server_position:
#			# Don't predict further than current time prediction (not that you could)
#			break_loop = true
#			prediction_period = _time_of_predicted_server_position - _since_server_frame_time[i]
#		else:
#			prediction_period = _since_server_frame_time[i + 1] - _since_server_frame_time[i]
#		if prediction_period > 0:
#			_apply_prediction_frame(i, prediction_period)
#		if break_loop:
#			break
#
#	var dx = _predicted_server_position.x - position.x
#	var dz = _predicted_server_position.z - position.z
#	print("Position Difference XZ:%f Y:%f" % [sqrt(dx * dx + dz * dz), \
#		_predicted_server_position.y - position.y])
##	print("psp:", _predicted_server_position, " pos:", position)
