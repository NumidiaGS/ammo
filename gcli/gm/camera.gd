# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, February 2022

extends Camera3D

@export_range(0.0, 1.0)
var sensitivity = 0.75

#####################
### Follow Target ###
#####################
# The target lookat height from the base of the character
var follow_height_offset = 4.0

# The distance back from the lookat point on the character
var follow_height_distance = 15
var follow_xz_distance = 15

# The follow target
var follow_target: Node3D = null
var prev_target_position: Vector3 = Vector3(0,0,0)

#####################
#####################
#####################
func vec2_from_angle(degrees: float):
	var rad = deg2rad(degrees)
	return Vector2(cos(rad), sin(rad))

var time = 0.0
const eps: float = 0.001

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _follow_target(delta, force_update: bool = false):
	# Obtain the current targets direction and camera direction
	var tar_dir = Vector2.UP.rotated(follow_target.get_rotation().y)
	var cam_tar_vec = Vector2(follow_target.position.x, follow_target.position.z) - Vector2(position.x, position.z)
	cam_tar_vec = cam_tar_vec.normalized()

	# Obtain the target angle and camera angle, in degrees, and the nearest difference
	var tar_ang = rad2deg(atan2(-tar_dir.y, tar_dir.x))
	var cam_tar_ang = rad2deg(atan2(cam_tar_vec.y, cam_tar_vec.x))
	var diff = tar_ang - cam_tar_ang
	var abs_diff = abs(diff)
	if(abs(diff) > 180.0):
		diff = sign(-diff) * (360 - abs(diff))
		abs_diff = abs(diff)
	
	# Check Conditions
	var pos_changed = follow_target.position != prev_target_position	
	if force_update || pos_changed || abs_diff > eps:
		var rot_adjustment = delta * (sign(diff) * 4.0 + diff * 1.4)
		if abs_diff < abs(rot_adjustment):
#			print("diff:%f rot_adjustment:%f" % [diff, rot_adjustment])
			cam_tar_ang = tar_ang
		else:
			cam_tar_ang += rot_adjustment
			
		time += delta
		if time > 1.4:
			time -= 0.4			
#			print("*diff:%f rot_adjustment:%f" % [diff, rot_adjustment])
	#		print("tar_dir: %f %f" % [tar_dir.x, tar_dir.y])
	#		print("tar_ang: %f  cam_tar_ang: %f  cam_tar_ang: %f" % [tar_ang, cam_tar_ang, cam_tar_ang])

		cam_tar_vec = vec2_from_angle(cam_tar_ang)
		var cam_offset = Vector3(-cam_tar_vec.x * follow_xz_distance, follow_height_distance, -cam_tar_vec.y * follow_xz_distance)

		prev_target_position = follow_target.position
		position = prev_target_position + cam_offset
		look_at(follow_target.position + Vector3(0, follow_height_offset, 0), Vector3.UP);

func set_follow_target(node: Node):
	follow_target = node
#	_follow_target(0.005, true)

func get_follow_target():
	return follow_target

# Mouse state
var _mouse_position = Vector2(0.0, 0.0)
var _total_pitch = 0.0

# Movement state
var _direction = Vector3(0.0, 0.0, 0.0)
var _velocity = Vector3(0.0, 0.0, 0.0)
var _acceleration = 40
var _deceleration = -20
var _vel_multiplier = 6

# Keyboard state
var _w = false
var _s = false
var _a = false
var _d = false
var _q = false
var _e = false

func _unhandled_input(event):
	print("camera(unused):", event)
	# Receives mouse motion
	if event is InputEventMouseMotion:
		_mouse_position = event.relative
	
	# Receives mouse button input
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT: # Only allows rotation if right click down
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
			MOUSE_BUTTON_WHEEL_UP: # Increases max velocity
				_vel_multiplier = clamp(_vel_multiplier * 1.1, 0.2, 20)
			MOUSE_BUTTON_WHEEL_DOWN: # Decereases max velocity
				_vel_multiplier = clamp(_vel_multiplier / 1.1, 0.2, 20)

func _unhandled_key_input(event: InputEvent):
	# Receives key input
	match event.keycode:
		KEY_W:
			_w = event.pressed
		KEY_S:
			_s = event.pressed
		KEY_A:
			_a = event.pressed
		KEY_D:
			_d = event.pressed
		KEY_Q:
			_q = event.pressed
		KEY_E:
			_e = event.pressed

# Updates mouselook and movement every frame
func _process(delta):
	if follow_target == null:
		_update_mouselook()
		_update_movement(delta)
	else:
		_follow_target(delta)

# Updates camera movement
func _update_movement(delta):
	# Computes desired direction from key states
	_direction = Vector3(float(_d), float(_e), float(_s))
	if _a:
		_direction.x -= 1.0
	if _q:
		_direction.y -= 1.0
	if _w:
		_direction.z -= 1.0
		
	# Computes the change in velocity due to desired direction and "drag"
	# The "drag" is a constant acceleration on the camera to bring it's velocity to 0
	var offset = _direction.normalized() * _acceleration * _vel_multiplier * delta \
		+ _velocity.normalized() * _deceleration * _vel_multiplier * delta
	
	# Checks if we should bother translating the camera
	if _direction == Vector3.ZERO and offset.length_squared() > _velocity.length_squared():
		# Sets the velocity to 0 to prevent jittering due to imperfect deceleration
		_velocity = Vector3.ZERO
	else:
		# Clamps speed to stay within maximum value (_vel_multiplier)
		_velocity.x = clamp(_velocity.x + offset.x, -_vel_multiplier, _vel_multiplier)
		_velocity.y = clamp(_velocity.y + offset.y, -_vel_multiplier, _vel_multiplier)
		_velocity.z = clamp(_velocity.z + offset.z, -_vel_multiplier, _vel_multiplier)
	
		translate(_velocity * delta)

# Updates mouse look 
func _update_mouselook():
	# Only rotates mouse if the mouse is captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_mouse_position *= sensitivity
		var yaw = _mouse_position.x
		var pitch = _mouse_position.y
		_mouse_position = Vector2(0, 0)
		
		# Prevents looking up/down too far
		pitch = clamp(pitch, -90 - _total_pitch, 90 - _total_pitch)
		_total_pitch += pitch
	
		rotate_y(deg2rad(-yaw))
		rotate_object_local(Vector3(1,0,0), deg2rad(-pitch))
