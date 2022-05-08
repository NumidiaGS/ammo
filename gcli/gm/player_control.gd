extends Node3D

class_name PlayerControl

var _mouse_left_down: bool = false
var _mouse_right_down: bool = false

var _time_left_down: int = 0
var _time_right_down: int = 0

var mouse_left_pressed: bool = false
var mouse_right_pressed: bool = false
var mouse_left_released: bool = false
var mouse_right_released: bool = false

var mouse_motion: Vector2 = Vector2.ZERO

var _control_events: Array

#var mouse_capture_enabled: bool = false
#var interact_enabled: bool = false

#func _unhandled_key_input(event):
#	if mouse_capture_enabled:
#		if event.is_action_pressed("ui_cancel"):
#			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#			mouse_capture_enabled = false
#		else:
#			if interact_enabled:
#				if event.is_action_released("d_use"):
#					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#					interact_enabled = false
#			else:
#				if event.is_action_pressed("d_use"):
#					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
#					interact_enabled = true
#	else:
#		if event.is_action_pressed("ui_cancel"):
#			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#			mouse_capture_enabled = true
#					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
#				else:
#					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

enum ControlMode {
	NULL = 0,
	Default,
	LeftDown,
	RightDown,
	CameraOrientation,
	CameraHold,
	ForwardMovementAndCameraOrientation,
}
var _control_mode: ControlMode

enum ControlEvents {
	NULL = 0,
	None,
	RightMouseButtonPress,
	LeftMouseButtonPress,
	RightMouseButtonClick,
	LeftMouseButtonClick,
	FreeMouseMotion,
	CameraHoldMotion,
	CameraOrientationMotion,
	ForwardMovementAndCameraOrientationMotion,
}

const ClickTimeoutThreshold: int = 350

func _process(_delta: float) -> void:
	# Process events
	if _control_events.size():
		for event in _control_events:
			match event[0]:
				ControlEvents.LeftMouseButtonPress:
					var _game_world: GameWorld = get_node("/root/Game/World") as GameWorld
					var screen_position = event[1]
					var result = _game_world.get_picking_collision($PlayerHeroFollowCamera.position,
						$PlayerHeroFollowCamera.project_ray_normal(screen_position), 20)
					print("get_picking_collision:", result)
				ControlEvents.CameraOrientationMotion:
					var mm: Vector2 = event[1]
					$PlayerHero.adjust_yaw(mm.x)
					$PlayerHeroFollowCamera.adjust_pitch(mm.y)
		_control_events.clear()
		
	# Process Mouse-Downs
	match _control_mode:
		ControlMode.LeftDown:
			if Time.get_ticks_msec() - _time_left_down >= ClickTimeoutThreshold:
				_control_mode = ControlMode.CameraHold
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		ControlMode.RightDown:
			if Time.get_ticks_msec() - _time_right_down >= ClickTimeoutThreshold:
				_control_mode = ControlMode.CameraOrientation
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Process View
#	match _control_mode:
		

func register_input_event(event: InputEvent) -> int:
	if event is InputEventMouseButton:
		# Convert into mouse control event
		var mouse_button_event: InputEventMouseButton = event
		match mouse_button_event.button_index:
			MOUSE_BUTTON_RIGHT:
				_mouse_right_down = mouse_button_event.pressed
				if _mouse_right_down:
					if _mouse_left_down:
						_control_mode = ControlMode.ForwardMovementAndCameraOrientation
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					else:
						_time_right_down = Time.get_ticks_msec()
						_control_mode = ControlMode.RightDown
						_control_events.append([ControlEvents.RightMouseButtonPress, \
							mouse_button_event.position])
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else:
					if _mouse_left_down:
						_control_mode = ControlMode.CameraHold
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					else:
						if _control_mode == ControlMode.RightDown:
							if Time.get_ticks_msec() - _time_right_down < ClickTimeoutThreshold:
								_control_events.append([ControlEvents.RightMouseButtonClick])
								# TODO ?? double-right-click?
						_control_mode = ControlMode.Default
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			MOUSE_BUTTON_LEFT:
				_mouse_left_down = mouse_button_event.pressed
				if _mouse_left_down:
					if _mouse_right_down:
						_control_mode = ControlMode.ForwardMovementAndCameraOrientation
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					else:
						_time_left_down = Time.get_ticks_msec()
						_control_mode = ControlMode.LeftDown
						_control_events.append([ControlEvents.LeftMouseButtonPress, \
							mouse_button_event.position])
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else:
					if _mouse_right_down:
						_control_mode = ControlMode.CameraOrientation
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					else:
						if _control_mode == ControlMode.LeftDown:
							if Time.get_ticks_msec() - _time_left_down < ClickTimeoutThreshold:
								_control_events.append([ControlEvents.LeftMouseButtonClick])
								# TODO ?? double-left-click?
						_control_mode = ControlMode.Default
						Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		match _control_mode:
			ControlMode.Default:
				if _control_events.size() > 0 and \
					_control_events[_control_events.size() - 1][0] == ControlEvents.FreeMouseMotion:
					# Add to previous event
					_control_events[_control_events.size() - 1][1] += motion_event.relative
				else:
					_control_events.append([ControlEvents.FreeMouseMotion, motion_event.relative])
			ControlMode.LeftDown:
				print("set to camerahold")
				_control_mode = ControlMode.CameraHold
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_control_events.append([ControlEvents.CameraHoldMotion, motion_event.relative])
			ControlMode.RightDown:
				_control_mode = ControlMode.CameraOrientation
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_control_events.append([ControlEvents.CameraOrientationMotion, \
					motion_event.relative])
			ControlMode.CameraHold:
				if _control_events.size() > 0 and \
					_control_events[_control_events.size() - 1][0] == ControlEvents.CameraHoldMotion:
					# Add to previous event
					_control_events[_control_events.size() - 1][1] += motion_event.relative
				else:
					_control_events.append([ControlEvents.CameraHoldMotion, motion_event.relative])
			ControlMode.CameraOrientation:
				if _control_events.size() > 0 and _control_events[_control_events.size() - 1][0] \
					== ControlEvents.CameraOrientationMotion:
					# Add to previous event
					_control_events[_control_events.size() - 1][1] += motion_event.relative
				else:
					_control_events.append([ControlEvents.CameraOrientationMotion, \
						motion_event.relative])
			ControlMode.ForwardMovementAndCameraOrientation:
				if _control_events.size() > 0 and _control_events[_control_events.size() - 1][0] \
					== ControlEvents.ForwardMovementAndCameraOrientationMotion:
					# Add to previous event
					_control_events[_control_events.size() - 1][1] += motion_event.relative
				else:
					_control_events.append([ControlEvents.ForwardMovementAndCameraOrientationMotion, \
						motion_event.relative])
	return 0
