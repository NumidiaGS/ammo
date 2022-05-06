extends Object

class_name GameWorld

const TargetTicksPerSecond: int = 45
const TickDelta: float = 1.0 / TargetTicksPerSecond
const StartupDelayPeriodUsecs: int = 1000000 * 5

const DeathTimeoutPeriod: float = 5.0

signal notification()

#####################################################################
#############################  Enums  ###############################
#####################################################################

enum OutgoingNotificationType {
	NULL = 0,
	PlayerDeath
}

enum DeathCauseType {
	NULL = 0,
	Starved,
}

#####################################################################
###########################  Properties  ############################
#####################################################################

var world_tick_count: int = 0
var tick_update_time: int
var max_tick_update_time: int
var rolling_tick_update_time: int

var chunks: Array

# Hero Movement Settings
# TODO Keep this Synchronized with server: /gcli/units/player/player_hero.gd
const HERO_GRAVITY: float = 18.6
const HERO_TERMINAL_VELOCITY: float = HERO_GRAVITY
const HERO_MAX_HORIZONTAL_VELOCITY: float = 8.0
const HERO_MAX_HORIZONTAL_VELOCITY_SQ: float = HERO_MAX_HORIZONTAL_VELOCITY * \
	HERO_MAX_HORIZONTAL_VELOCITY
const HERO_IMPULSE: float = 36.0
const HERO_JUMP_IMPULSE: float = 13.0

#####################################################################
########################  Private Variables  ########################
#####################################################################

var _thread: Thread
var _thread_mutex: Mutex = Mutex.new()
var _quit_thread: bool = false

var _heroes: Array = []
var _map_objects: Array = []

#var _queued_interactions: Array = []
#var _interactions: Array = []

var outgoing_notifications: Array
var _queued_notifications: Array

func begin_async() -> int:
	_thread = Thread.new()
	_quit_thread = false
	var err: int = _thread.start(Callable(_thread_function))
	if err != OK:
		_quit_thread = true
	return err

# Thread must be disposed (or "joined"), for portability.
func end_async():
	_thread_mutex.lock()
	_quit_thread = true
	_thread_mutex.unlock()
	_thread.wait_to_finish()

# Run here and exit.
# The argument is the userdata passed from start().
# If no argument was passed, this one still needs to
# be here and it will be null.
func _thread_function():
	const TickUpdatePeriodUsecs: int = 1000000 / TargetTicksPerSecond
	const DelayPeriodUsecs: int = 500
	
	var last_update: int = Time.get_ticks_usec() + StartupDelayPeriodUsecs # 5 second startup wait
	
	# Monitor Loop
	while true:
		# Tick Timing
		var server_time_usec: int = Time.get_ticks_usec()
		if server_time_usec - last_update < TickUpdatePeriodUsecs:
			OS.delay_usec(DelayPeriodUsecs)
			continue
		last_update += TickUpdatePeriodUsecs
		if server_time_usec - last_update >= TickUpdatePeriodUsecs:
			last_update = server_time_usec
		
		# Check for quit
		_thread_mutex.lock()
		if _quit_thread:
			print("quitting world>:thread safely")
			return
		
		# Transfer all client input in
		_transfer_client_input()
		_thread_mutex.unlock()
		
		# Update the world a tick
		_tick_world()
		
		# Transfer all world events out
		_thread_mutex.lock()
		_transfer_world_notifications()
		
		tick_update_time = Time.get_ticks_usec() - last_update
		max_tick_update_time = max(tick_update_time, max_tick_update_time)
		rolling_tick_update_time = (98 * rolling_tick_update_time + 2 * tick_update_time) / 100
		_thread_mutex.unlock()

#####################################################################
#######################  Input Data Transfer  #######################
#####################################################################

func _transfer_client_input() -> void:
#	interactions.append_array(_queued_interactions)
#	_queued_interactions.clear()
	pass

# Returns a flag indicating if any notifications are output
func _transfer_world_notifications() -> bool:
	if _queued_notifications.size() == 0:
		return false
	outgoing_notifications.append_array(_queued_notifications)
	_queued_notifications.clear()
	return true

#####################################################################
##########################  World Update  ###########################
#####################################################################

func _tick_world() -> void:
	_update_heroes()
	_update_interactions()
	
	world_tick_count += 1

func _update_interactions() -> void:
	# Copy
	var interactions: Array = []
	
	for i in interactions:
		var player_acc: PlayerAccount = i[0]
		var map_object: MapObject = i[1]
		
		# Using match for layout
		match map_object.interaction_behaviour:
			MapObject.InteractionBehaviour.BerryBush:
				print("and here...", map_object.object_uid, ":", player_acc.hero.inventory_0)
			_:
				print("ERROR] Player '%s' sent unrecognized interaction type = %d" % [ \
					player_acc.hero.nickname, map_object.interaction_type])

func _update_heroes() -> void:
	for hero in _heroes:
		if hero.dead != 0.0:
			hero.dead += TickDelta
			if hero.dead >= DeathTimeoutPeriod:
				# Respawn hero
				hero.dead = 0.0
				hero.satiation = 100
			continue
		
		# # Movement & Interaction
		# Client Movement Reports
		if hero.cmr_modified:
			hero.cmr_modified = false
			
			# TODO @ some point:
			# - Movement Validation
			# - Collision Checking
			# - Adjustments if need be
			hero.position = hero.cmr_position
			hero.yaw = hero.cmr_yaw
#			print("hero_position:", hero.position)
		
		# # State Updates
		# Satiation
		hero.satiation -= TickDelta * 1.0
#		print("%s: %f" % [hero.nickname, hero.satiation])
		if hero.satiation <= 0.0:
			hero.dead = TickDelta
			_queued_notifications.append([OutgoingNotificationType.PlayerDeath, hero.uid, \
				DeathCauseType.Starved])
			print("hero %s died" % [hero.nickname])
			continue
	
		# Move to the hero yaw
		# TODO -- add a rotational speed limit / input-rotation-direction-field?
#		hero.yaw = hero.input_yaw
#
#		# Determine impulse
#		var impulse: Vector2 = Vector2.ZERO
#		if hero.input_mask & hero.HERO_INPUT_MoveForward:
#			impulse.y = 1.0
#		if hero.input_mask & hero.HERO_INPUT_MoveBackward:
#			impulse.y = -1.0
#		if hero.input_mask & hero.HERO_INPUT_StrafeLeft:
#			impulse.x = 1.0
#		if hero.input_mask & hero.HERO_INPUT_StrafeRight:
#			impulse.x = -1.0
#		if hero.is_grounded and hero.input_mask & hero.HERO_INPUT_Jump:
#			hero.is_grounded = false
#			hero.velocity.y = HERO_JUMP_IMPULSE
#		impulse = impulse.rotated(-hero.yaw).normalized() * delta * HERO_IMPULSE
#
#		# Decay previous frames velocity
#		var decay: float = 1.0 - 5.0 * delta
#		hero.velocity.x *= decay
#		hero.velocity.z *= decay
#
#		# Apply impulse
#		hero.velocity.x += impulse.x
#		hero.velocity.z += impulse.y
#		if hero.velocity.x * hero.velocity.x + hero.velocity.z * hero.velocity.z > \
#			HERO_MAX_HORIZONTAL_VELOCITY_SQ:
#			var speed = sqrt(hero.velocity.x * hero.velocity.x + hero.velocity.z * hero.velocity.z)
#			hero.velocity.x /= speed / HERO_MAX_HORIZONTAL_VELOCITY
#			hero.velocity.z /= speed / HERO_MAX_HORIZONTAL_VELOCITY
#			print("Hero Maxed")
#		if !hero.is_grounded:
#			hero.velocity.y -= HERO_GRAVITY * delta
#			if hero.velocity.y < -HERO_TERMINAL_VELOCITY:
#				hero.velocity.y = -HERO_TERMINAL_VELOCITY
#
#		# Cut off small horizontal velocity
#		if hero.velocity.x * hero.velocity.x + hero.velocity.z * hero.velocity.z < 0.005:
#			hero.velocity.x = 0.0
#			hero.velocity.z = 0.0
#
#		# Determine any collisions
#		var hero_aabb: AABB = AABB(hero.position + Vector3(0, 0.8, 0), Vector3(0.5, 0.8, 0.5))
#		for obj in _map_objects:
#			var aabb: AABB = obj[0]
#			if hero_aabb.intersects(aabb):
#				var mobj: MapObject = obj[1]
#				match mobj.interaction_behaviour:
#					MapObject.InteractionBehaviour.BerryBush:
#						hero.digestion = min(hero.max_digestion, hero.digestion + 1)
#					_:
#						pass
##				print("Intersection with:", mobj.object_resource
#
#		if hero.position.y + hero.velocity.y * delta <= 0.0:
#			hero.is_grounded = true
#			hero.position.y = 0.0
#			hero.velocity.y = 0.0
#
#		# Apply velocity
#		hero.position += hero.velocity * delta
#
##		if hero.velocity.y != 0.0:
##			print("hero.velocity", hero.velocity)
		
## DEBUG
#func _move_debug_char(delta: float):
#	var db_target: Vector3 = Vector3(debug_pc_wp[debug_pc_wp_idx].x, 0, \
#		debug_pc_wp[debug_pc_wp_idx].z)
#	var dbpc_move: Vector3 = db_target - debug_pc.hero.pos
#	var dbpc_speed = delta * 3
#	if dbpc_move.length() < dbpc_speed:
#		debug_pc.hero.pos = db_target
#		debug_pc.hero.rot = debug_pc_wp[debug_pc_wp_idx].y
#		debug_pc_wp_idx += 1
#		if debug_pc_wp_idx >= debug_pc_wp.size():
#			debug_pc_wp_idx = 0
#	else:
#		dbpc_move = dbpc_move.normalized() * dbpc_speed
#		debug_pc.hero.pos += dbpc_move
#	# DEBUG

func add_hero(hero: HeroData) -> void:
	# Add to index
	_heroes.append(hero)

func remove_hero(hero: HeroData) -> void:
	# Find from index
	var idx: int = _heroes.rfind(hero)
	if idx >= 0:
		_heroes.remove_at(idx)

func add_map_object(obj: MapObject, position_offset: Vector3) -> void:
	match obj.object_type:
		MapObject.ObjectType.StaticInteractable:
			var collision_shape: Shape3D
			for child in obj.get_children():
				if child is CollisionShape3D:
					collision_shape = child.shape
					break
			if not collision_shape:
				print("Error] StaticInteractable Object '%s' parent='%s' does not have a " \
					% [obj.name, obj.get_parent_node_3d().name] + "collision shape")
				return
			var aabb_size: Vector3 = Vector3.ZERO
			match collision_shape.get_class():
				"BoxShape3D":
					aabb_size = collision_shape.size
				"SphereShape3D":
					aabb_size = Vector3(collision_shape.radius, collision_shape.radius, \
						collision_shape.radius)
				_:
					print("ERROR]world::add_map_object:> Unsupported collision shape for object=" \
						+ "'%s' (parent='%s'), shape='%s'" % [obj.name, \
						obj.get_parent_node_3d().name, collision_shape.get_class()])
			var aabb: AABB = AABB(position_offset + obj.position, aabb_size)
			_map_objects.append([aabb, obj, position_offset, collision_shape])
		_:
			pass

#func remove_map_object(obj: MapObject) -> void:
#	# Find from index
#	var idx: int = _map_objects.rfind(obj)
#	if idx >= 0:
#		_map_objects.remove_at(idx)
#

#func enqueue_interaction(player_acc: PlayerAccount, map_object: MapObject) -> void:
#	_enqueue_mutex.lock()
#	_queued_interactions.push_back([player_acc, map_object])
#	_enqueue_mutex.unlock()

func register_chunk(mc_data: SerializedMapChunk) -> void:
	chunks.append(mc_data)
