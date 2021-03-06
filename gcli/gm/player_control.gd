# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, March 2022

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
var _mouse_down_position: Vector2 = Vector2.ZERO
var mouse_motion: Vector2 = Vector2.ZERO

var _picked_object: MapObject

var _control_events: Array
@onready var _game_world: GameWorld = get_node("/root/Game/World") as GameWorld

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

func _process(delta: float) -> void:
	# Process events
	if _control_events.size():
		for event in _control_events:
			match event[0]:
				ControlEvents.CameraOrientationMotion:
					var mm: Vector2 = event[1]
					$PlayerHero.adjust_yaw(mm.x)
					$PlayerHeroFollowCamera.adjust_pitch(mm.y)
				ControlEvents.ForwardMovementAndCameraOrientationMotion:
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
		ControlMode.ForwardMovementAndCameraOrientation:
			$PlayerHero.move_forward(delta)
		ControlMode.Default:
			var screen_position = get_viewport().get_mouse_position()
			_picked_object = _game_world.get_picking_collision($PlayerHeroFollowCamera.position,
				$PlayerHeroFollowCamera.project_ray_normal(screen_position), 12.0, \
				$PlayerHero.position)
#			print("_pick_selection:", _picked_object)
	
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
						_mouse_down_position = mouse_button_event.position
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
						get_viewport().warp_mouse(_mouse_down_position)
			MOUSE_BUTTON_LEFT:
				_mouse_left_down = mouse_button_event.pressed
				if _mouse_left_down:
					if _mouse_right_down:
						_control_mode = ControlMode.ForwardMovementAndCameraOrientation
						Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
					elif _picked_object:
						print("selection:", _picked_object, "[", \
							_picked_object.interaction_behaviour, "]")
						_begin_interact_with_object(_picked_object);
						pass
					else:
						_time_left_down = Time.get_ticks_msec()
						_control_mode = ControlMode.LeftDown
						_control_events.append([ControlEvents.LeftMouseButtonPress, \
							mouse_button_event.position])
						_mouse_down_position = mouse_button_event.position
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
						if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
							Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
							get_viewport().warp_mouse(_mouse_down_position)
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

func _begin_interact_with_object(obj: MapObject):
	match obj.interaction_behaviour:
		MapObject.InteractionBehaviour.TownStockpile:
			var stockpile_interface: StockpileInterface = get_node("/root/Game/GUI/StockpileInterface")
#			print("stockpile_interface:", stockpile_interface)
			
			# Make visible
			stockpile_interface.display(obj.object_uid)
		MapObject.InteractionBehaviour.TownFoundationStone:
			var tfs_interface: FoundationStoneIF = get_node("/root/Game/GUI/FoundationStoneIF")
			
			# Make visible
			tfs_interface.display(obj.object_uid)
		_:
			pass
