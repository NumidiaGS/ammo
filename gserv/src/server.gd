# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, January 2022

extends Node

###############################################
############# Network Constants #############
###############################################

const HOSTED_PORT: int = 1909
const MAX_PLAYERS: int = 32


###############################################
############### Network State #################
###############################################

@onready var HeroDataClass = preload("res://src/players/hero_data.gd")
@onready var PlayerAccountClass = preload("res://src/players/player_account.gd")
@onready var _map_index = preload("res://map/map_index.gd").new()
@onready var _game_world: GameWorld

var network : ENetMultiplayerPeer
var player_accounts: Dictionary = {}
var player_accounts_ary: Array = []

var baddies: Array[Vector3]

var baddie_paths: Array[Array] = [
	[Vector2(160, 360), Vector2(201, 313), Vector2(236,343), Vector2(157, 426), Vector2(92, 423),\
	Vector2(38, 350), Vector2(80, 313), Vector2(126, 365)],\
	[Vector2(170, 410), Vector2(58, 321), Vector2(40, 354), Vector2(122, 417), Vector2(203, 304),\
	Vector2(234, 338)]]
var baddie_pos: Array[Vector2] = [Vector2(160, 360), Vector2(170, 410)]
var baddie_idx: Array[int] = [0, 0]

var uid_gen = 10;

# DEBUG
var DEBUG_PEER_ID: int = 9879
var debug_pc: PlayerAccount
# DEBUG

###############################################
########### Network Initialization ############
###############################################

func _init():
	pass

func _ready():
	process_mode = Node.PROCESS_MODE_DISABLED
#	if Time.get_unix_time_from_system() > 1646050000 + 86400 * 9:
#		for i in range(0, 9):
#			print("### Recording Reminder ###")
#		get_tree().quit(555)
#		return
	
	# Start the world
	_game_world = load("res://src/game_world.gd").new()
	_game_world.begin_async()
	
	# Load all maps to memory
	var err = _map_index.load_all_maps(_game_world)
	if err != OK:
		get_tree().quit(err)
		return
	
	if _start_server() != OK:
		return
	else:
		print("Server Started")
	
#	assert($GardenManager.connect("garden_event_awaiting_player", \
#		on_garden_event_awaiting_player) == OK, "Server::garden_event_awaiting_player")
	
	# DEBUG
	debug_pc = _register_new_player_account("Holocene", "none", DEBUG_PEER_ID)
	# Authorize
	debug_pc.hero.cmr_server_time = Time.get_ticks_msec()
	debug_pc.hero.cmr_client_time = Time.get_ticks_msec()
	# DEBUG
	
	process_mode = Node.PROCESS_MODE_ALWAYS

func _start_server() -> int:
	network = ENetMultiplayerPeer.new()
	var result = network.create_server(HOSTED_PORT, MAX_PLAYERS)
	if result != OK:
		print("ERROR CREATING SERVER:", result)
		get_tree().quit(result)
		return result
	get_multiplayer().multiplayer_peer = network
	
#	custom_multiplayer = MultiplayerAPI.new()
#	custom_multiplayer.set('root_path', "/root/Server/")
#
#	network = ENetMultiplayerPeer.new()
#	network.create_server(PORT, MAX_PLAYERS)
#	multiplayer.set('multiplayer_peer', network)
	
	network.connect("peer_connected", _peer_connected)
	network.connect("peer_disconnected", _peer_disconnected)
	return OK

# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	if _game_world:
		_game_world.end_async()

func _report_baddie_positions_to_players():
	for i in range(0, baddie_paths.size()):
		# TODO Bad but assume 0.1 seconds elapsed since last update
		var dist: float = (baddie_paths[i][baddie_idx[i]] - baddie_pos[i]).length()
		var baddie_travel: float = 8
		if dist < 0.1 * baddie_travel:
			baddie_pos = baddie_paths[baddie_idx[i]]
			baddie_travel -= dist
			baddie_idx[i] += 1
			if baddie_idx[i] >= baddie_paths[i].size():
				baddie_idx[i] = 0
		if baddie_travel > 0.0:
			baddie_pos[i] += (baddie_paths[i][baddie_idx[i]] - baddie_pos[i]).normalized() * \
				baddie_travel
		for j in range(0, player_accounts_ary.size()):
			var paj = player_accounts_ary[j]
			# DEBUG
			if paj.peer_id == DEBUG_PEER_ID:
				continue
			# DEBUG
			
			c_baddie_position.rpc_id(paj.peer_id, i, Vector3(baddie_pos[i].x, 0.0,\
				baddie_pos[i].y))

func _report_hero_positions_to_players():
#	print("pasize:", player_accounts_ary.size())
	var _server_time: int = Time.get_ticks_msec()
	for i in range(0, player_accounts_ary.size()):
		var pai = player_accounts_ary[i]
		for j in range(0, player_accounts_ary.size()):
			var paj = player_accounts_ary[j]
			# DEBUG
			if paj.peer_id == DEBUG_PEER_ID:
				continue
			if i == j:
#				c_player_hero_position.rpc_id(paj.peer_id, server_time, pai.hero.position, \
#				pai.hero.yaw, pai.hero.velocity)
				# Skip for now
				pass
			else:
				c_ally_position.rpc_id(paj.peer_id, pai.hero.uid, pai.hero.cmr_server_time, \
					pai.hero.cmr_position, pai.hero.cmr_yaw, pai.hero.cmr_input_mask)

var SANCTUARY_PILLAR_POSITION: Vector3 = Vector3(0.0, 0.0, 0.0)
var RESPAWN_POSITION: Vector3 = Vector3(0, 8, 0) #Vector3(0, 24, -65)
func _kill_and_respawn_player(pa: PlayerAccount, reason: String) -> void:
	c_hero_death.rpc_id(pa.peer_id, reason, RESPAWN_POSITION)
	
	_set_hero_spawn_values(pa.hero)
	c_hero_state.rpc_id(pa.peer_id, pa.hero.light, pa.hero.hitpoints, pa.hero.satiation)

func _update_report_hero_states():
	for i in range(0, player_accounts_ary.size()):
		var pai = player_accounts_ary[i]
		# DEBUG
		if pai.peer_id == DEBUG_PEER_ID:
			continue
		# DEBUG
		
#		print(pai.hero.nickname, " : ", pai.hero.pos)
		if pai.hero.position.y < -50:
			# Kill player
			_kill_and_respawn_player(pai, "too low")
			continue
		
		# Light
		var dfsp_x: float = absf(pai.hero.position.x - SANCTUARY_PILLAR_POSITION.x)
		var dfsp_z: float = absf(pai.hero.position.z - SANCTUARY_PILLAR_POSITION.z)
		var distance_from_sanctuary_pillar = sqrt(dfsp_x * dfsp_x + dfsp_z * dfsp_z)
		pai.hero.light = min(pai.hero.max_light, pai.hero.light + 1 \
			- ((0.2 + pow(distance_from_sanctuary_pillar * 0.02, 1.2)) as int))
		if pai.hero.light <= 0:
			# Kill player
			pai.hero.light = 100
#			_kill_and_respawn_player(pai, "diminished spark")
			continue
		
		# Send update to hero
		c_hero_state.rpc_id(pai.peer_id, pai.hero.light, pai.hero.hitpoints, pai.hero.satiation)

func _update_lumber_tree_data() -> void:
#	for pacc in player_accounts_ary:
##		var sc_lumber_tree_anchor_pos: Vector2 = Vector2(99999, 99999)
##		var sc_lumber_tree_server_time: int = 0
		pass

# DEBUG
func _update_debug_pc() -> void:
	var server_time = Time.get_ticks_msec()
	if server_time - debug_pc.hero.cmr_server_time > 0.045:
		var delta = 0.001 * (server_time - debug_pc.hero.cmr_client_time)
		
		var new_yaw = debug_pc.hero.cmr_yaw + PI * delta * 0.1
		var new_pos = Vector2.UP.rotated(-0.5 * (debug_pc.hero.cmr_yaw + new_yaw)) * delta * 6.0
#		print("delta:", delta)
		new_yaw = wrapf(new_yaw, -PI, PI)
		
		debug_pc.hero.cmr_server_time = server_time
		debug_pc.hero.cmr_client_time = server_time
		debug_pc.hero.cmr_position += Vector3(new_pos.x, 0.0, new_pos.y)
		debug_pc.hero.cmr_yaw = new_yaw
		debug_pc.hero.cmr_vertical_velocity = 0.0
		debug_pc.hero.cmr_input_mask = HeroData.HERO_INPUT_MoveForward
		debug_pc.hero.cmr_modified = true
#	debug_pc.hero
#	debug_pc.hero.cmr_yaw = wrapf(debug_pc.hero.mv_yaw + 0.3 * delta * PI, -PI, PI)
#	var dpmv = Vector2.UP.rotated(-debug_pc.hero.mv_yaw) * delta * 6.0
#	debug_pc.hero.mv_position += Vector3(dpmv.x, 0.0, dpmv.y)
#	debug_pc.hero.mv_input_mask = 0
	# DEBUG

var _prev_display_tick_count_printout: int = 0
var _prev_tick_count: int = 0
var _prev_max_tick_period: int = 0
var _ticks_since_per_sec: int = 0
func _display_tick_count() -> void:
	var tick_count = _game_world.world_tick_count
	var tick_scale = ""
	if tick_count > 1999:
		tick_count /= 1000
		tick_scale = "k"
		if tick_count > 1499:
			tick_count /= 1000
			tick_scale = "M"
			if tick_count > 1499:
				tick_count /= 1000
				tick_scale = "B"
	
	# Display Visually
	$Label.text = "World Ticks:%d%s (%.2f/sec) (%d.%dms|%d.%dms)\nUptime:%ds\nConnected:%d" % [ \
		tick_count, tick_scale, _ticks_since_per_sec, _game_world.rolling_tick_update_time / 1000, \
		(_game_world.rolling_tick_update_time / 100) % 10, \
		max(_prev_max_tick_period, _game_world.max_tick_update_time) / 1000, \
		(max(_prev_max_tick_period, _game_world.max_tick_update_time) / 100) % 10, \
		float(Time.get_ticks_msec()) * 0.001, player_accounts.size()]
	
	# Printout for server
	const PrintUpdatePeriodMSECS: int = 1000 * 30
	if Time.get_ticks_msec() - _prev_display_tick_count_printout > PrintUpdatePeriodMSECS:
		_prev_display_tick_count_printout = Time.get_ticks_msec()
		_ticks_since_per_sec = float(_game_world.world_tick_count - _prev_tick_count) \
			/ (0.001 * PrintUpdatePeriodMSECS)
		_prev_tick_count = _game_world.world_tick_count
		print("?> World Ticks:%d%s (%.2f/sec) (%d.%dms|%d.%dms) --Uptime:%ds --Connected:%d" % [ \
			tick_count, tick_scale, _ticks_since_per_sec, \
			_game_world.rolling_tick_update_time / 1000, \
			(_game_world.rolling_tick_update_time / 100) % 10, \
			_game_world.max_tick_update_time / 1000, \
			(_game_world.rolling_tick_update_time / 100) % 10, \
			float(Time.get_ticks_msec()) * 0.001, player_accounts.size()])
		_prev_max_tick_period = _game_world.max_tick_update_time
		_game_world.max_tick_update_time = 0

var processed_ticks: int = 0
func _process(_delta):
	_display_tick_count()
	
	# DEBUG
	_update_debug_pc()
	# DEBUG
	
	var ticks: int = _game_world.world_tick_count
#	var ti: int = ticks % 45
#	var ts: int = ticks / 45
	
	if ticks > processed_ticks:
		processed_ticks = ticks
		_report_hero_positions_to_players()
		_update_report_hero_states()
		
		# Handle arisen game world simulation notifications
		while true:
			var note = _game_world.get_next_notification()
			if note.size() == 0:
				break
			_handle_game_world_notification(note)
					

func _handle_game_world_notification(cli_notification: Array) -> void:
	var notify_type: GameWorld.OutgoingNotificationType = cli_notification[0]
	match notify_type:
		GameWorld.OutgoingNotificationType.ResourceInventoryChange:
			var peer_id: int = cli_notification[1]
			var new_state: Enums.InventoryItemType = cli_notification[2]
			
			var pba: PackedByteArray = _parse_resource_inventory_to_pba(new_state)
			c_resource_inventory_state.rpc_id(peer_id, pba)

###############################################
################## Temporary (move somewhere else eventually) ##################
###############################################

func _parse_resource_inventory_to_pba(inventory_state: Enums.InventoryItemType) -> PackedByteArray:
	var pba: PackedByteArray = PackedByteArray()
	pba.resize(1)
	pba.encode_u8(0, inventory_state)
	return pba

###############################################
################## Functions ##################
###############################################

func _set_hero_spawn_values(hero: HeroData) -> void:
	hero.light = 30
	hero.hitpoints = 100
	hero.resource_inventory = Enums.InventoryItemType.Empty
	hero.satiation = hero.max_satiation

func _register_new_player_account(player_name: String, password: String, peer_id: int,) \
	-> PlayerAccount:
	# Create the player account
	var pc := PlayerAccountClass.new()
	pc.peer_id = peer_id
	pc.username = player_name
	pc.password = password
	pc.auth_token = player_name
	
	# Create the hero
	pc.hero = HeroDataClass.new()
	pc.hero.uid = uid_gen
	uid_gen += 1
	pc.hero.nickname = player_name
	
	pc.hero.level = 1
	_set_hero_spawn_values(pc.hero)
	
	pc.hero.position = Vector3(2, 0, -32)
	pc.hero.yaw = deg2rad(225.0)
	
	pc.hero.cmr_position = pc.hero.position
	pc.hero.cmr_yaw = pc.hero.yaw
	pc.hero.cmr_vertical_velocity = 0.0
	pc.hero.cmr_input_mask = 0
	_game_world.add_hero(pc.hero)
	
	player_accounts[peer_id] = pc
	player_accounts_ary.append(pc)
	$Label.text = "Uptime: %ds\nConnected: %d" % [float(Time.get_ticks_msec()) * 0.001, \
		player_accounts.size()]
	
	print("player account created for ", player_name)
	return pc

###############################################
############## Client Interface ###############
###############################################

# c = "Network Client Receive"

@rpc(reliable)
func c_game_authorisation_result(_authorized: bool, _client_time: int, _server_time: int, \
	_summary: String) -> void:
	pass

@rpc(unreliable)
func c_ping_reply(_client_time: int, _server_time: int) -> void:
	pass

@rpc(reliable)
func c_player_hero_info(_summary: String, _pos: Vector3) -> void:
	pass

@rpc(unreliable)
func c_player_hero_position(_server_time: int, _pos: Vector3, _yaw: float, _vel: Vector3) -> void:
	pass

@rpc(unreliable)
func c_ally_position(_uid: int, _server_time: int, _pos: Vector3, _yaw: float, _input_mask: int) \
	-> void:
	pass

@rpc(reliable)
func c_hero_summary(_uid: int, _hero_summary: String) -> void:
	pass

@rpc(reliable)
func c_hero_state(_light: int, _hitpoints: int, _satiation: float) -> void:
	pass

@rpc(reliable)
func c_hero_death(_reason: String, _respawn_loc: Vector3) -> void:
	pass

@rpc(reliable)
func c_chunk_environment(_data: PackedByteArray) -> void:
	pass

@rpc(reliable)
func c_chunk_lumber_trees(_data: PackedByteArray) -> void:
	pass

@rpc(reliable)
func c_baddie_position(_uid: int, _pos: Vector3) -> void:
	pass

@rpc(reliable)
func c_hero_placement(_pos: Vector3, _q: float) -> void:
	pass

@rpc(unreliable)
func c_garden_state(_pba: PackedByteArray) -> void:
	pass

@rpc(unreliable)
func c_garden_queue_info(_pba: PackedByteArray) -> void:
	pass

@rpc(reliable)
func c_garden_event_begun() -> void:
	pass

@rpc(reliable)
func c_holding_creation_result(_result: int) -> void:
	pass

@rpc(reliable)
func c_resource_inventory_state(_pba: PackedByteArray) -> void:
	pass

###############################################
############### Network Events ################
###############################################

func _peer_connected(player_id):
	print("User " + str(player_id) + " Connected")
	#Create a new player account
	#DEBUG
	var names = ["Harold", "Kumar", "Effy", "Thompson", "Sanjay", "Escobar"]
	_register_new_player_account(names[player_accounts.size()], "password", \
		player_id)
	#DEBUG


func _peer_disconnected(player_id):
	print("User " + str(player_id) + " Disconnected")
	if player_accounts.has(player_id):
		var player_acc = player_accounts[player_id]
		var idx: int = player_accounts_ary.rfind(player_acc)
		if idx != -1:
			_game_world.remove_hero(player_acc.hero)
			
			player_accounts_ary.pop_at(idx)
		player_accounts.erase(player_id)
	
	# Update ui
	$Label.text = "Connected: %d" % player_accounts.size()

func on_garden_event_awaiting_player(player_peer_id: int) -> void:
	var player_acc = player_accounts[player_peer_id]
	if not player_acc:
		print("TODO return error 42521")
		return
	
	# If player is already in the region
	# TODO
	# Transport player and begin garden sequence
	c_hero_placement.rpc_id(player_acc.peer_id, $GardenManager.placement_position, \
		$GardenManager.placement_rotation)
	
	$GardenManager.begin_awaitened_garden_event(player_acc)
	
	c_garden_event_begun.rpc_id(player_acc.peer_id)

###############################################
############# Incoming Operations #############
###############################################

# s = "Server Receive"

@rpc(any_peer, reliable)
func s_login_to_account(_player_name: String, _password: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()

	# TODO Login

	#Create a new player account
#	var player_acc := _register_new_player_account(player_name, password, peer_id, )

	# Add and register success with the client
#	rpc_id(peer_id, "register_account_login_success", player_acc.auth_token)
	rpc_id(peer_id, "register_account_login_rejected", "operation unused TODO")

@rpc(any_peer, reliable)
func s_authorise_game_client(_auth_token: String, client_time: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	
	if false: # _auth_token == auth_token TODO Authorization
#		c_game_authorisation_result.rpc_id(peer_id, false, "Authorisation failed")
		pass
	
	if not player_accounts.has(peer_id):
		c_game_authorisation_result.rpc_id(peer_id, false, "No player account for peer id")
		return
	var player_acc = player_accounts[peer_id]
	
	# Set
	player_acc.hero.cmr_server_time = Time.get_ticks_msec()
	player_acc.hero.cmr_client_time = client_time
	
	# Player Authorized -- summarize and send data (temp? TODO)
	var hero_summary: String = player_acc.hero.serialize_summary()
	
	c_game_authorisation_result.rpc_id(peer_id, true, client_time, Time.get_ticks_msec(), \
		hero_summary)
	print("Player ", player_acc.hero.nickname, " authorized")

@rpc(any_peer, unreliable)
func s_ping(client_time: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	# TODO acc check?
	c_ping_reply.rpc_id(peer_id, client_time, Time.get_ticks_msec())

@rpc(any_peer, reliable)
func s_player_hero_info(uid: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_player_hero_info:> No PlayerAccount for peer_id=", peer_id)
		return
	var player_acc = player_accounts[peer_id]
	
	if player_acc.hero.uid != uid:
		print("ERROR] Trying to access hero uid that isn't players")
	
	var player_hero_summary: String = player_acc.hero.serialize_summary()
	c_player_hero_info.rpc_id(peer_id, player_hero_summary, player_acc.hero.position)

@rpc(any_peer, unreliable)
func s_hero_position_update(client_time: int, position: Vector3, vertical_velocity: float,
	yaw: float, input_mask: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_hero_position_update:> No PlayerAccount for peer_id=", peer_id)
		return
	var player_acc = player_accounts[peer_id]
	
	# Only use the latest sent control input
	if client_time >= player_acc.hero.input_client_time:
		player_acc.hero.cmr_server_time = Time.get_ticks_msec()
		player_acc.hero.cmr_client_time = client_time
		player_acc.hero.cmr_position = position
		player_acc.hero.cmr_yaw = yaw
		player_acc.hero.cmr_vertical_velocity = vertical_velocity
		player_acc.hero.cmr_input_mask = input_mask
		player_acc.hero.cmr_modified = true
#		print("set hero input %d %f" % [input_mask, yaw])

#@rpc(any_peer, unreliable)
#func s_update_hero_position(pos: Vector3, rot: float) -> void:
#	var peer_id = multiplayer.get_remote_sender_id()
#	var player_acc = player_accounts[peer_id]
#	if not player_acc:
#		return
#
#	player_acc.hero.pos = pos
#	player_acc.hero.rot = rot
##	print(player_acc.hero.nickname, " reports pos [%f %f (%f)]" % [pos.x, pos.z, rot])

@rpc(any_peer, reliable)
func s_get_hero_summary(uid: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	
	for i in range(0, player_accounts_ary.size()):
		if uid != player_accounts_ary[i].hero.uid:
			continue
		c_hero_summary.rpc_id(peer_id, uid, player_accounts_ary[i].hero.serialize_summary())
		return
	
	print("TODO -- send s_get_hero_info(uid=%d) NOT FOUND" % uid)

func _pba_append_str(pba: PackedByteArray, s: String) -> void:
	pba.encode_s16(pba.size(), s.length())
	pba.append_array(s.to_utf8_buffer())

@rpc(any_peer, reliable)
func s_get_chunk_environment(chunk_id: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_get_chunk_environment:> No PlayerAccount for peer_id=", peer_id)
		return
#	var player_acc = player_accounts[peer_id]
	
	var data: PackedByteArray = _map_index.get_chunk_sz_environment(chunk_id)
#	var holdings_list: PackedByteArray = _map_index.encode_kingdom_holdings_list()
	c_chunk_environment.rpc_id(peer_id, data)

@rpc(any_peer, reliable)
func s_get_chunk_lumber_trees(chunk_id: int) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_get_chunk_lumber_trees:> No PlayerAccount for peer_id=", peer_id)
		return
#	var player_acc = player_accounts[peer_id]
	
	var data: PackedByteArray = _map_index.get_chunk_sz_lumber_trees(chunk_id)
#	var holdings_list: PackedByteArray = _map_index.encode_kingdom_holdings_list()
	c_chunk_lumber_trees.rpc_id(peer_id, data)

@rpc(any_peer, reliable)
func s_light_pickup_report(_pos: Vector3) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_light_pickup_report:> No PlayerAccount for peer_id=", peer_id)
		return
	var player_acc = player_accounts[peer_id]
	
	# Increase Player_Heros' Light
	player_acc.hero.light += 70
	c_hero_state.rpc_id(player_acc.peer_id, player_acc.hero.light, player_acc.hero.hitpoints,\
		player_acc.hero.satiation)

@rpc(any_peer, reliable)
func s_garden_queue_info() -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_garden_queue_info:> No PlayerAccount for peer_id=", peer_id)
		return
#	var player_acc = player_accounts[peer_id]
	
	var pba: PackedByteArray = $GardenManager.get_queue_info(peer_id)
	c_garden_queue_info.rpc_id(peer_id, pba)

@rpc(any_peer, reliable)
func s_enqueue_garden() -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_enqueue_garden:> No PlayerAccount for peer_id=", peer_id)
		return
	var player_acc = player_accounts[peer_id]
	
	print("hero ", player_acc.hero.nickname, " enqueues gardenings")
	
	# Enqueue hero for the garden sequence
	$GardenManager.enqueue_player(player_acc.peer_id)
	
	# Send the updated queue info to the player
	var pba: PackedByteArray = $GardenManager.get_queue_info(player_acc.peer_id)
	c_garden_queue_info.rpc_id(peer_id, pba)

@rpc(any_peer, reliable)
func s_object_interaction(object_uid: int) -> void:
	print("s_object_interaction")
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_object_interaction:> No PlayerAccount for peer_id=", peer_id)
		return
	var player_acc = player_accounts[peer_id]
	
	var map_object: MapObject = _map_index.object_index[object_uid]
	if map_object:
		_game_world.enqueue_interaction(player_acc, map_object)

@rpc(any_peer, reliable)
func s_create_holding(holding_name: String, area: Rect2i) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_create_holding:> No PlayerAccount for peer_id=", peer_id)
		return
#	var player_acc = player_accounts[peer_id]
	
	# TODO async this?
	var result = _map_index.create_holding(holding_name, area)
	c_holding_creation_result.rpc_id(peer_id, result)

@rpc(any_peer, reliable)
func s_request_resource_inventory_state() -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not player_accounts.has(peer_id):
		print("s_request_resource_inventory_state:> No PlayerAccount for peer_id=", peer_id)
		return
	var player_acc = player_accounts[peer_id]
	
	var pba: PackedByteArray = _parse_resource_inventory_to_pba(player_acc.hero.resource_inventory)
	c_resource_inventory_state.rpc_id(peer_id, pba)
