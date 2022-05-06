extends Node

##############################
########## Signals ###########
##############################

signal account_login_successful(first_character_summary)
signal player_hero_info_received(serialized_summary, hero_position)
signal player_hero_position_update(server_time, pos, yaw, vel)
signal ally_position_update(uid, server_time, pos, yaw, input_mask)
signal hero_summary_received(uid, hero_summary)
signal hero_state_received(light, hitpoints, satiation)
signal player_hero_death(reason, respawn_location)
signal map_data_received(map, property_list)
signal chunk_lumber_trees_received(data)
signal player_hero_placement(position, yaw)
signal baddie_position_update(uid, pos)
signal garden_queue_info_received(info)
signal garden_state_received(state)
signal garden_event_begun_for_player()

##############################
########## Settings ##########
##############################

##############################
########## Variables #########
##############################

var network : ENetMultiplayerPeer
var server_peer_id: int = 1

var callbacks: Dictionary

# Server time & latency in msecs
var game_server_time_offset: int = 0
var game_server_latency: int = 0
var _game_server_ping_timer: Timer = Timer.new()

##############################
####### Initialization #######
##############################

func _ready():
	pass

# Gets the current estimated server time (in msecs)
func get_current_server_time() -> int:
	return Time.get_ticks_msec() + game_server_time_offset

##############################
###### Server Interface ######
##############################

# s = "Server Receive"

@rpc(reliable)
func s_authorise_game_client(_auth_token: String, _client_time: int) -> void:
	pass

@rpc(reliable)
func s_login_to_account(_player_name: String, _password: String) -> void:
	pass

@rpc(unreliable)
func s_ping(_client_time: int) -> void:
	pass

@rpc(reliable)
func s_player_hero_info(_hero_uid: int) -> void:
	pass

@rpc(unreliable)
func s_hero_position_update(_client_time: int, _position: Vector3, _vertical_velocity: float,
	_yaw: float, _input_mask: int) -> void:
	pass

#@rpc(unreliable)
#func s_update_hero_position(_pos: Vector3, _rot: float) -> void:
#	pass

@rpc(reliable)
func s_get_hero_summary(_uid: int) -> void:
	pass

# TODO depreciated
@rpc(reliable)
func s_get_chunk_environment(_chunk_id: int) -> void:
	pass
	
@rpc(reliable)
func s_get_chunk_lumber_trees(_chunk_id: int) -> void:
	pass

@rpc(reliable)
func s_light_pickup_report(_pos: Vector3) -> void:
	pass

@rpc(reliable)
func s_garden_queue_info() -> void:
	pass

@rpc(reliable)
func s_enqueue_garden() -> void:
	pass

@rpc(reliable)
func s_object_interaction(_object_uid: int) -> void:
	pass

@rpc(reliable)
func s_create_holding(_holding_name: String, _area: Rect2i) -> void:
	pass

##############################
##### Outgoing Operations ####
##############################

const GAME_CONNECTION: String = "GAME_CONNECTION"
func begin_game_connection(ip: String, port: int, callback: Callable) -> int:
	# TODO -- check for existing connection dont just make a new one
	
	network = ENetMultiplayerPeer.new()
	var err = network.create_client(ip, port)
	if err == OK:
		get_multiplayer().multiplayer_peer = network
		print("connecting to Game Server...")
		
		network.connect("connection_failed", _on_server_connect_failure)
		network.connect("connection_succeeded", _on_server_connect_succeeded)
		callbacks[GAME_CONNECTION] = callback
	else:
		print("Error creating network client: ", err)
	return err

const GAME_SERVER_AUTHORIZATION: String = "GAME_SERVER_AUTHORIZATION"
func authorise_to_game_server(auth_token: String, callback: Callable) -> void:
	print("authorise_to_game_server")
	callbacks[GAME_SERVER_AUTHORIZATION] = callback
	s_authorise_game_client.rpc_id(server_peer_id, auth_token, Time.get_ticks_msec())

func get_player_hero_info(hero_uid: int) -> void:
	s_player_hero_info.rpc_id(server_peer_id, hero_uid)

func send_hero_control_update(position: Vector3, vertical_velocity: float, yaw: float, \
	input_mask: int) -> void:
	s_hero_position_update.rpc_id(server_peer_id, Time.get_ticks_msec(), position, \
		vertical_velocity, yaw, input_mask)

#func update_hero_position(pos: Vector3, q: float) -> void:
#	s_update_hero_position.rpc_id(server_peer_id, pos, q)
##	print("report at [%f %f %f (%f)]" % [pos.x, pos.y, pos.z, q])
#	pass
func get_hero_summary(uid: int) -> void:
	s_get_hero_summary.rpc_id(server_peer_id, uid)
	pass

func get_map_data(chunk_id: int) -> void:
	s_get_chunk_environment.rpc_id(server_peer_id, chunk_id)

func report_light_pickup(pos: Vector3) -> void:
	s_light_pickup_report.rpc_id(server_peer_id, pos)

func request_garden_queue_info() -> void:
	s_garden_queue_info.rpc_id(server_peer_id)

func enqueue_garden_event() -> void:
	s_enqueue_garden.rpc_id(server_peer_id)

func interact_with_object(object_uid: int) -> void:
	s_object_interaction.rpc_id(server_peer_id, object_uid)

func create_holding(holding_name: String, area: Rect2i) -> void:
	s_create_holding.rpc_id(server_peer_id, holding_name, area)

func temp_get_world_data() -> void:
	s_get_chunk_environment.rpc_id(server_peer_id, 0)

func get_chunk_lumber_trees(chunk_index: int) -> void:
	s_get_chunk_lumber_trees.rpc_id(server_peer_id, chunk_index)

##############################
########### Events ###########
##############################

func _on_game_server_ping_timeout() -> void:
	s_ping.rpc_id(server_peer_id, Time.get_ticks_msec())

func _on_server_connect_failure() -> void:
	print("Failed to connect to game server")
	if not callbacks.has(GAME_CONNECTION):
		return
	var callback: Callable = callbacks[GAME_CONNECTION]
	callback.call(false)
	callbacks.erase(GAME_CONNECTION)

func _on_server_connect_succeeded() -> void:
	print("Successfully connected to game server")
	if not callbacks.has(GAME_CONNECTION):
		return
	var callback: Callable = callbacks[GAME_CONNECTION]
	callback.call(true)
	callbacks.erase(GAME_CONNECTION)
	
	# Begin the game server ping timer
	_game_server_ping_timer.timeout.connect(_on_game_server_ping_timeout)
	_game_server_ping_timer.wait_time = 2.0
	add_child(_game_server_ping_timer)
	_game_server_ping_timer.start()

##############################
##### Incoming Operations ####
##############################

# c = "Network Client Receive"
# DO NOT call these from this client

@rpc(authority, reliable)
func c_game_authorisation_result(result: bool, client_time: int, server_time: int, \
	hero_data: String) -> void:
	# Update the server time
	game_server_latency = (Time.get_ticks_msec() - client_time) / 2
	game_server_time_offset = server_time - (client_time + game_server_latency)
	
	# Callback Client Authorisation Result
#	print("c_game_authorisation_result")
	if not callbacks.has(GAME_SERVER_AUTHORIZATION):
		return
	var callback: Callable = callbacks[GAME_SERVER_AUTHORIZATION]
	callback.call(result, hero_data)
	callbacks.erase(GAME_SERVER_AUTHORIZATION)

@rpc(authority, unreliable)
func c_ping_reply(client_time: int, server_time: int) -> void:
#	print("Estimated Server Time:%d  Actually:%d (%d) Latency=%d" \
#		% [client_time + game_server_latency + game_server_time_offset, server_time, \
#			server_time - (client_time + game_server_latency + game_server_time_offset), \
#			game_server_latency])
	
	# Update the server time
	game_server_latency = (2 * game_server_latency + (Time.get_ticks_msec() - client_time)) / 4
	game_server_time_offset = (game_server_time_offset + server_time - \
		(client_time + game_server_latency)) / 2
#	print("Server Time: %d  (%dms)" % [client_time + game_server_time_offset, \
#		game_server_latency])

@rpc(reliable)
func c_player_hero_info(hero_summary: String, hero_position: Vector3) -> void:
	emit_signal("player_hero_info_received", hero_summary, hero_position)

@rpc(authority, unreliable)
func c_player_hero_position(server_time: int, pos: Vector3, yaw: float, vel: Vector3) -> void:
	emit_signal("player_hero_position_update", server_time, pos, yaw, vel)

@rpc(authority, unreliable)
func c_ally_position(uid: int, server_time: int, pos: Vector3, yaw: float, input_mask: int) \
	-> void:
	emit_signal("ally_position_update", uid, server_time, pos, yaw, input_mask)

@rpc(authority, reliable)
func c_hero_summary(uid: int, hero_summary: String) -> void:
	emit_signal("hero_summary_received", uid, hero_summary)

@rpc(authority, reliable)
func c_hero_state(light: int, hitpoints: int, satiation: float) -> void:
	emit_signal("hero_state_received", light, hitpoints, satiation)

@rpc(authority, reliable)
func c_hero_death(reason: String, respawn_loc: Vector3) -> void:
	emit_signal("player_hero_death", reason, respawn_loc)

@rpc(authority, reliable)
func c_chunk_environment(data: PackedByteArray) -> void:
	emit_signal("map_data_received", data)

@rpc(authority, reliable)
func c_chunk_lumber_trees(data: PackedByteArray) -> void:
	emit_signal("chunk_lumber_trees_received", data)

@rpc(authority, reliable)
func c_baddie_position(uid: int, pos: Vector3) -> void:
	emit_signal("baddie_position_update", uid, pos)

@rpc(authority, reliable)
func c_hero_placement(pos: Vector3, q: float) -> void:
	emit_signal("player_hero_placement", pos, q)

@rpc(authority, unreliable)
func c_garden_queue_info(info: PackedByteArray) -> void:
	emit_signal("garden_queue_info_received", info)

@rpc(authority, unreliable)
func c_garden_state(state: PackedByteArray) -> void:
#	print("pba:", state)
	emit_signal("garden_state_received", state)

@rpc(authority, reliable)
func c_garden_event_begun() -> void:
	emit_signal("garden_event_begun_for_player")

@rpc(reliable)
func c_holding_creation_result(result: int) -> void:
	print("c_holding_creation_result:", result)
