extends Node3D

const ALLY_LATENT_UPDATE_PERIOD: int = 120

var hero_serialization: Object = preload("res://units/hero_serialization.gd")
var ally_hero_scene: PackedScene = preload("res://units/ally/ally_hero.tscn")

var _ally_heroes: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	assert(Server.connect("ally_position_update", on_ally_position_update) == OK, \
		"Couldnt connect to Server::hero_position_update")
	assert(Server.connect("hero_summary_received", on_hero_summary_received) == OK, \
		"Couldnt connect to Server::hero_summary_received")
	
#	hero_info_received
	pass
	


#var prev_player_pos: Vector3
#var last_light_drop: int = 0
#var light_globule: Node3D = preload("res://iables/light_pickup/light_pickup.tscn").instantiate()
#var light_globules_to_drop: Array[Node3D] = []
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
#	if player_hero.position != prev_player_pos:
#		prev_player_pos = player_hero.positon

#	# Light Drops
#	if last_light_drop + 4000 < Time.get_ticks_msec():
#		last_light_drop = Time.get_ticks_msec()
#
#		# Drop a light pickup
#		var light: Node3D = light_globule.duplicate()
#		light_globules_to_drop.push_back(light)
#		print("Light Spawned")
	pass

func _physics_process(_delta):
	var server_latent_msecs: int = Server.get_current_server_time() - ALLY_LATENT_UPDATE_PERIOD
	for ally in _ally_heroes.values():
#		print("server_latent_msecs:", server_latent_msecs, " ally.recent_server_time:", \
#			ally.recent_server_time)
#		if server_latent_msecs >= ally.recent_server_time:
#			# Extrapolate TODO
#			ally.position = ally.recent_server_position
#			ally.rotation = Vector3(0.0, ally.recent_server_yaw, 0.0)
#		else:
		var interp: float = (float(server_latent_msecs) - ally.previous_server_time) \
			/ (ally.recent_server_time - ally.previous_server_time)
		ally.position = ally.recent_server_position + (ally.recent_server_position - \
			ally.previous_server_position) * interp
		# TODO one day -- rotate 175 to -175 not by way of the 350-degree difference etc.
		ally.rotation = Vector3(0.0, ally.recent_server_yaw + (ally.recent_server_yaw - \
			ally.previous_server_yaw) * interp, 0.0)
			
#	while light_globules_to_drop.size() > 0:
#		var light: Node3D = light_globules_to_drop.pop_back()
#		var space_state = get_world_3d().direct_space_state
#		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
#		var success: bool = false
#		for i in range(0, 10):
#			query.from = Vector3(player_hero.position.x - 10.0 + randf() * 20.0,\
#				player_hero.position.y + 10, player_hero.position.z - 10.0 + randf() * 20.0)
#			query.to = query.from + Vector3.DOWN * 50.0
#
#			var result = space_state.intersect_ray(query)
#			if result:
#				print("result:", result)
#				light.position = result.position + Vector3.UP * 1.1
#				$LightPickups.add_child(light)
#				success = true
#				break
#		if !success:
#			light.free_queue()

#func set_player_summary(hero_summary: String) -> void:
#	# DEBUG TODO
#	player_hero.initialize_world_location(Vector3(0, 2, -4), 0)
#
#	assert(player_hero.connect("light_pickup_collision", on_hero_light_pickup) == OK, \
#		"Couldnt connect to PlayerHero::light_pickup_collision")

func on_ally_position_update(uid: int, server_update_time: int, pos: Vector3, yaw: float, \
	_input_mask: int) -> void:
	var ally_hero: Node3D
	if _ally_heroes.has(uid):
		# Update ally hero position
#		print("ally %d is at [%f %f %f]" % [uid, pos.x, pos.y, pos.z])
		ally_hero = _ally_heroes[uid]
#		print("Received Ally Position @ server:%d  est_server:%d  (%d)" % [server_update_time, \
#			Server.get_current_server_time(), Server.get_current_server_time() - server_update_time])
		if ally_hero.recent_server_time < server_update_time:
			ally_hero.previous_server_time = ally_hero.recent_server_time
			ally_hero.previous_server_position = ally_hero.recent_server_position
			ally_hero.previous_server_yaw = ally_hero.recent_server_yaw
	else:
		# Create a placeholder hero_data
		ally_hero = ally_hero_scene.instantiate()
		ally_hero.hero_uid = uid
		ally_hero.hero_name = "Unknown"
		ally_hero.position = pos
		ally_hero.rotation = Vector3(0.0, yaw, 0.0)
		ally_hero.set('disabled', true)
		_ally_heroes[uid] = ally_hero
		add_child(ally_hero)
		
		ally_hero.previous_server_time = server_update_time - 100
		ally_hero.previous_server_position = pos
		ally_hero.previous_server_yaw = yaw
		
		# Send a request to server to obtain information about the hero
		Server.get_hero_summary(uid)
	
	# Set
	ally_hero.recent_server_time = server_update_time
	ally_hero.recent_server_position = pos
	ally_hero.recent_server_yaw = yaw

func on_hero_summary_received(uid: int, serialized_hero_summary: String) -> void:
	if _ally_heroes.has(uid):
		var ally_hero: Node3D = _ally_heroes[uid]
		var hero_summary = hero_serialization.deserialize_hero_summary(serialized_hero_summary)
		if hero_summary[hero_serialization.SUMMARY_UID] != uid:
			print("ERROR] uids do not match 48171")
		ally_hero.hero_name = hero_summary[hero_serialization.SUMMARY_NAME]
		ally_hero.set('disabled', false)
		return
	
	print("TODO -- received hero info for hero not instantiated...")

func on_hero_light_pickup(light_pickup_object: Node3D) -> void:
	Server.report_light_pickup(light_pickup_object.position)
	$LightPickups.remove_child(light_pickup_object)
	light_pickup_object.call_deferred("free")
