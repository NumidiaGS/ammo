# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, April 2022

extends Node

class_name GameSceneLoader

const MSECS_5_MINUTES: int = 300000
const MSECS_10_MINUTES: int = 600000

const SIZE_IN_BYTES_Transform3D: int = 13 * 4

########################################
################ Temp ##################
########################################
var temp_map_data: PackedByteArray

########################################
############## Variables ###############
########################################
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _quit_thread: bool = false

var _map_resources: Dictionary = {}

var _player_hero: PlayerHero
var _units_node: Node3D
var _world_node: Node3D
#var _world_kingdom_node: Node3D

var HeroSerializationScript: Script = preload("res://units/hero_serialization.gd")
var KingdomPropertyInfoScript: Script = preload("res://map/kingdom_property_info.gd")
var MapChunkScript: Script = preload("res://map/map_chunk.gd")

# Next Update Times
var _initial_load_progress: int = 0 # 100 is complete
var _nr_player_hero_info: int = 0
var _nr_player_hero_info_rrq: int = 0
var _nr_map_lumber_trees: int = 0
var _nr_map_lumber_trees_rrq: int = 0
#var _nr_init_harvest_lumber: int = 0
#var _nr_init_harvest_lumber_rrq: int = 0

func get_scene_viability():
	return _initial_load_progress

func begin_async(player_hero: PlayerHero, world_node: Node3D, units_node: Node3D) -> void:
	_player_hero = player_hero
	_world_node = world_node
#	_world_kingdom_node = world_node.get_child(0)
	_units_node = units_node
	
	_thread = Thread.new()
	_thread.start(Callable(_thread_function))

# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	_mutex.lock()
	_quit_thread = true
	_mutex.unlock()
	_thread.wait_to_finish()

# Run here and exit.
# The argument is the userdata passed from start().
# If no argument was passed, this one still needs to
# be here and it will be null.
func _thread_function():
	_load_resource_objects()
	_connect_to_server_signals()
	_load_map_chunks()
	
	# Initial Loop
	while true:
		_mutex.lock()
		if _quit_thread:
			print("quitting game_scene_loader>:thread safely")
			return
		
		var complete = _initial_data_attainment()
		_mutex.unlock()
		
		if complete:
			break
		OS.delay_msec(5)
	
	# Monitor Loop
	while true:
		_mutex.lock()
		if _quit_thread:
			print("quitting game_scene_loader>:thread safely")
			return
		
		_maintain_data()
		_mutex.unlock()
		
		OS.delay_msec(1)

func _connect_to_server_signals() -> void:
	assert(Server.connect("player_hero_info_received", _on_player_hero_info_received) == OK,\
		"Server::player_hero_info_received")
	assert(Server.connect("chunk_lumber_trees_received", _on_chunk_lumber_trees_received) == OK,\
		"Server::chunk_lumber_trees_received")

func _initial_data_attainment() -> bool:
	var msecs: int = Time.get_ticks_msec()
	
	# Make 1 request per cycle
	if msecs > _nr_player_hero_info:
		if msecs > _nr_player_hero_info_rrq:
			Server.get_player_hero_info(_player_hero.hero_uid)
			_nr_player_hero_info_rrq = msecs + 1000
		return false
	_initial_load_progress = max(_initial_load_progress, 10)
	
	if msecs > _nr_map_lumber_trees:
		if msecs > _nr_map_lumber_trees_rrq:
			Server.get_chunk_lumber_trees(0)
			_nr_map_lumber_trees_rrq = msecs + 1000
		return false
	
	_initial_load_progress = max(_initial_load_progress, 100)
	return true

func _maintain_data():
	var msecs: int = Time.get_ticks_msec()
	
	# Make 1 request per cycle
	if msecs > _nr_player_hero_info && msecs > _nr_player_hero_info_rrq:
		Server.get_player_hero_info(_player_hero.hero_uid)
		_nr_player_hero_info_rrq = msecs + 1000
		return
#	if msecs > _nr_map_data && msecs > _nr_map_data_rrq:
#		Server.get_map_data(0)
#		_nr_map_data_rrq = msecs + 1000
#		return

##########################################
############### Map Loading ##############
##########################################

func _load_resource_objects() -> void:
	var asset_index: File = File.new()
	asset_index.open("res://map/assets/asset_index.txt", File.READ)
	while not asset_index.eof_reached():
		var line = asset_index.get_line()
#		print("Line:'%s'" % [line])
		if line.length() > 4:
			var specs = line.split(';', false)
			if specs.size() == 4:
				var res_id = specs[1].to_int()
				var path = specs[3]
				
				_map_resources[res_id] = load(path)
				print("loaded map resource:", specs[0])
	asset_index.close()

# TODO -- doesn't appear to be in use
func _get_child_node_with_name(parent: Node, child_name: String) -> Node:
	for child in parent.get_children():
		if child.name == child_name:
			return child
	return null

func _instantiate_map_resource(obj_res_id: MapObject.ResourceIdentity) -> MapObject:
	if !_map_resources.has(obj_res_id):
		print("ERROR]game_scene_loader:_instantiate_map_resource>: ", \
			"Unknown obj_res_id:", obj_res_id)
		return preload("res://map/assets/debug_object/debug_object.tscn").instantiate()
	
	var mobj: MapObject = _map_resources[obj_res_id].instantiate()
	mobj.resource_id = obj_res_id
	return mobj

func _decode_map_child(pba: PackedByteArray, pba_offset: int) -> Array:
	# Common Header
	var decoded_uid: int = pba.decode_s32(pba_offset)
	pba_offset += 4
	var object_type: int = pba.decode_s16(pba_offset)
	pba_offset += 2
	
	# Create
	var map_object: MapObject
	match object_type:
		MapObject.ObjectType.KingdomHolding:
			var kh: KingdomHolding = KingdomHolding.new()
			
			kh.holding_type = pba.decode_s16(pba_offset) as KingdomHolding.HoldingType
			pba_offset += 2
			var child_count: int = pba.decode_s16(pba_offset)
			pba_offset += 2
			
			print("TODO -- encode/decode KH Position Offset")
			
			while child_count > 0:
				var res = _decode_map_child(pba, pba_offset)
				var child: Node3D = res[0]
				if not child:
					kh.call_deferred("free")
					return [null, pba_offset]
				child_count -= 1
				kh.add_child(child)
				
				pba_offset = res[1]
			kh.holding_uid = decoded_uid
			return [kh, pba_offset]
		MapObject.ObjectType.StaticSolid, \
		MapObject.ObjectType.StaticInteractable:
			var interaction_behaviour = pba.decode_s16(pba_offset) as MapObject.InteractionBehaviour
			pba_offset += 2
			var obj_res_id: int = pba.decode_s32(pba_offset)
			pba_offset += 4
			
			print("MapObject:", obj_res_id)
			
			var tsfm: Transform3D = bytes2var(pba.slice(pba_offset, pba_offset + \
				SIZE_IN_BYTES_Transform3D))
			pba_offset += SIZE_IN_BYTES_Transform3D
			
			map_object = _instantiate_map_resource(obj_res_id)
			map_object.interaction_behaviour = interaction_behaviour
			
			# Set the transform and add the object
			map_object.transform = tsfm
			map_object.object_uid = decoded_uid
			map_object.object_type = object_type as MapObject.ObjectType
			
			return [map_object, pba_offset]
		_:
			print("ERROR]game_scene_loader:_decode_map_child>: Unknown object_type:", \
				object_type)
			return [null, pba_offset]

func _decode_map_chunk(pba: PackedByteArray) -> MapChunk:
	var map_chunk: MapChunk = MapChunkScript.new()
	
	var pba_offset: int = 0
	var pba_expected_size = pba.decode_u32(pba_offset)
	pba_offset += 4
	if pba.size() != pba_expected_size:
		print("ERROR]game_scene_loader:_decode_map_data_node>: Kingdom Map DL Size mismatch, ",
			pba.size(), "!=", pba_expected_size)
		return map_chunk
	
	map_chunk.location.x = pba.decode_s16(pba_offset)
	pba_offset += 2
	map_chunk.location.y = pba.decode_s16(pba_offset)
	pba_offset += 2
	map_chunk.bounds = AABB(Vector3(map_chunk.location.x - MapChunk.Extents.x, -MapChunk.Extents.y, \
		map_chunk.location.y - MapChunk.Extents.z), MapChunk.Extents * 2)
	var child_count = pba.decode_u16(pba_offset)
	pba_offset += 2
	
#	var _mi: MeshInstance3D = TerrainMeshGen.create_mesh(pba, pba_offset)
#	map_chunk.add_child(mi)
#	pba_offset += TerrainMeshGen.TerrainRes * TerrainMeshGen.TerrainRes
	
	while pba_offset < pba_expected_size and child_count > 0:
		var res = _decode_map_child(pba, pba_offset)
		var child: Node3D = res[0]
		if not child:
			map_chunk.call_deferred("free")
			return null
		child_count -= 1
		map_chunk.add_child(child)
		pba_offset = res[1]
		
	return map_chunk

func _load_map_chunks() -> void:
	var map_chunk = _decode_map_chunk(temp_map_data)
	_world_node.add_chunk(map_chunk)

##########################################
############ Request Callbacks ###########
##########################################

func _on_player_hero_info_received(serialized_hero_summary: String, hero_position: Vector3) \
	-> void:
	print("_on_player_hero_info_received>:Entered")
	_mutex.lock()
	_nr_player_hero_info = Time.get_ticks_msec() + MSECS_5_MINUTES
	_mutex.unlock()
	
	_player_hero.mutex.lock()
	var hero_summary = HeroSerializationScript.deserialize_hero_summary(serialized_hero_summary)
	_player_hero.hero_name = hero_summary[HeroSerializationScript.SUMMARY_NAME]
	
	_player_hero.position = hero_position
	# TODO fix when you dont call the method below
	_player_hero.register_server_hero_record(Server.get_current_server_time(), \
		hero_position, PI / 2, Vector3.ZERO)
	_player_hero.mutex.unlock()
	print("_on_player_hero_info_received>:Leaving")

func _on_chunk_lumber_trees_received(data: PackedByteArray) -> void:
	_mutex.lock()
	_nr_map_lumber_trees = Time.get_ticks_msec() + MSECS_5_MINUTES
	_mutex.unlock()
	
	if data.size() < 8:
		print("[Error] _on_chunk_lumber_trees_received:> Bad Data Size (0)")
		return
	var pba_offset: int = 0
	
	var chunk_loc: Vector2i = Vector2i.ZERO
	chunk_loc.x = data.decode_s16(pba_offset)
	chunk_loc.y = data.decode_s16(pba_offset)
	print("TODO -- not sure this is how it is server side")
	pba_offset += 4
	
	var lt_count = data.decode_u32(pba_offset)
	pba_offset += 4
	
	const LumberTreeByteSize: int = (4 + 4 * 3)
	if data.size() != 8 + lt_count * LumberTreeByteSize:
		print("[Error] _on_chunk_lumber_trees_received:> Bad Data Size (1)")
		return
	
	var all_trees: Array = []
	for i in range(0, lt_count):
		var lt_obj = preload("res://map/assets/tree/tree.tscn").instantiate() as MapObject
		
		lt_obj.object_uid = data.decode_u32(pba_offset)
		var lumber_pos: Vector3 = Vector3.ZERO
		lumber_pos.x = data.decode_float(pba_offset + 4)
		lumber_pos.y = data.decode_float(pba_offset + 8)
		lumber_pos.z = data.decode_float(pba_offset + 12)
		pba_offset += LumberTreeByteSize
		
		# TODO ?? transform instead of position
		lt_obj.position = lumber_pos
		all_trees.append(lt_obj)
	
	# TODO - redo this
	_world_node.reset_chunk_trees(chunk_loc, all_trees)



#	# TODO Holdings
#	var holdings: Array = []
#	var hl_offset: int = 0
#
#	var holdings_count: int = holdings_list.decode_s16(hl_offset)
#	hl_offset += 2
#	print("holdings_count:", holdings_count)
#	print("holdings_list:", holdings_list)
#
#	while hl_offset < holdings_list.size() and holdings.size() < holdings_count:
#		var ret = KingdomHolding.decode_from_byte_array(holdings_list, hl_offset)
#		holdings.append(ret)
#		hl_offset += KingdomHolding.EncodedByteSize
#		print("ret:", ret.holding_uid, "|", ret.holding_type)
	
#	print("_on_map_data_received>:Leaving")
