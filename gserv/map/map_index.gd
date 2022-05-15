# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, February 2022

extends RefCounted

var KingdomHoldingClass: GDScript = preload("res://map/kingdom_holding.gd")

var resources: Dictionary = {}
var _mc_0_0: SerializedMapChunk

var object_uid_counter: int = 1000
var object_index: Dictionary

func _get_resource_id(resource_name: String) -> int:
	match resource_name:
		"GreenGrid":
			return 101
	print("ERROR)_get_resource_code>: resource '%s' has no id" % [resource_name])
	return 0

# A transform encodes 52 bytes
func _encode_transform(pba: PackedByteArray, offset: int, transform: Transform3D) -> int:
	var tba = var2bytes(transform)
	if pba.size() < offset + tba.size():
		print("ERROR)_encode_transform>: pba has not enough space")
	for i in range(0, tba.size()):
		pba[offset + i] = tba[i]
	return offset + tba.size()

func _get_node_path_string(mi: Node3D) -> String:
	var node_path: String = mi.name
	var parent = mi.get_parent_node_3d()
	while parent:
		node_path = parent.name + "->" + node_path
		parent = parent.get_parent_node3d()
	return node_path

# Returns tuple [was_parsed: bool, new_pba_offset: int]
func _append_map_object_to_pba(pba: PackedByteArray, pba_offset: int, \
	_parent_offset: Vector3, mi: MapObject) -> Array:
	# Assign unique object uids
	mi.object_uid = object_uid_counter
	object_index[object_uid_counter] = mi
	object_uid_counter += 1
	
	# Add to world physics
#	world.add_map_object(mi, parent_offset)
	
	match mi.object_type:
		MapObject.ObjectType.ServerOnly:
			return [false, pba_offset]
		MapObject.ObjectType.KingdomHolding:
			print("ERROR) Should not reach here: _append_map_object_to_pba::MAPOBJ_TYPE_??=", \
				mi.object_type)
			return [false, pba_offset]
		MapObject.ObjectType.StaticSolid, \
		MapObject.ObjectType.StaticInteractable:
			# Resize Array
			const SIZE: int = 4 + 2 + 2 + 4 + 52
			if pba.size() < pba_offset + SIZE:
				pba.resize((pba.size() + SIZE) * 2)
			
			# Common Header
			pba.encode_s32(pba_offset, mi.object_uid)
			pba_offset += 4
			pba.encode_s16(pba_offset, mi.object_type)
			pba_offset += 2
	
			if not mi.interaction_behaviour:
				print("ERROR) Please assign an interaction type to map node:'%s'" % \
					[_get_node_path_string(mi)])
			pba.encode_s16(pba_offset, mi.interaction_behaviour)
			pba_offset += 2
			
#			var resource_id = _get_resource_id(mi.object_resource)
#			if resource_id == 0:
#				return PackedByteArray()
			if not mi.resource_id:
				print("ERROR) Please assign an interaction type to map node:'%s'" % \
					[_get_node_path_string(mi)])
			pba.encode_s32(pba_offset, mi.resource_id)
			pba_offset += 4
			
			pba_offset = _encode_transform(pba, pba_offset, mi.transform)
			return [true, pba_offset]
		MapObject.ObjectType.LightPickup:
			# Resize Array
			const SIZE: int = 4 + 2 + 12
			if pba.size() < pba_offset + SIZE:
				pba.resize((pba.size() + SIZE) * 2)
			
			# Common Header
			pba.encode_s32(pba_offset, mi.object_uid)
			pba_offset += 4
			pba.encode_s16(pba_offset, mi.object_type)
			pba_offset += 2
	
			pba.encode_float(pba_offset, mi.position.x)
			pba_offset += 4
			pba.encode_float(pba_offset, mi.position.y)
			pba_offset += 4
			pba.encode_float(pba_offset, mi.position.z)
			pba_offset += 4
			return [true, pba_offset]
		MapObject.ObjectType.Relic:
			# Resize Array
			const SIZE: int = 4 + 2 + 12
			if pba.size() < pba_offset + SIZE:
				pba.resize((pba.size() + SIZE) * 2)
			
			# Common Header
			pba.encode_s32(pba_offset, mi.object_uid)
			pba_offset += 4
			pba.encode_s16(pba_offset, mi.object_type)
			pba_offset += 2
			
			pba.encode_float(pba_offset, mi.position.x)
			pba_offset += 4
			pba.encode_float(pba_offset, mi.position.y)
			pba_offset += 4
			pba.encode_float(pba_offset, mi.position.z)
			pba_offset += 4
			return [true, pba_offset]
		_:
			print("ERROR)_parse_map_to_pba>: map-child-node='%s', Unknown MapObject Type:%s" % \
				[_get_node_path_string(mi), mi.object_type])
			return [false, pba_offset]
#	print("ERROR) _append_map_object_to_pba, Logic flow: Should not reach here")
#	return [false, pba_offset]

# Returns tuple [was_parsed: bool, new_pba_offset: int]
func _encode_map_child_to_pba(pba: PackedByteArray, pba_offset: int, \
	positional_offset: Vector3, child: Node3D) -> Array:
	
	if child.visible == false:
		return [false, pba_offset]
	
	if child is MapObject:
		# Delegate
		return _append_map_object_to_pba( pba, pba_offset, positional_offset, child)
#	elif child is KingdomHolding:
#		# Resize
#		const SIZE: int = 4 + 2 + 2 + 2
#		if pba.size() < pba_offset + SIZE:
#			pba.resize((pba.size() + SIZE) * 2)
#
#		# Common Header
#		var kh: KingdomHolding = child
#		pba.encode_s32(pba_offset, kh.holding_uid)
#		pba_offset += 4
#		pba.encode_s16(pba_offset, MapObject.ObjectType.KingdomHolding)
#		pba_offset += 2
#		pba.encode_s16(pba_offset, kh.holding_type)
#		pba_offset += 2
#
#		var cc_off = pba_offset
#		pba_offset += 2
#		var gc_count = 0
#
#		for grandchild in child.get_children():
#			var res = _parse_map_child_to_pba(world, pba, pba_offset, positional_offset + \
#				child.position, grandchild)
#			var was_parsed: bool = res[0]
#			pba_offset = res[1]
#
#			if was_parsed:
#				gc_count += 1
#		pba.encode_s16(cc_off, gc_count)
#
#		return [true, pba_offset]
	elif child is KingdomHolding or child is SpawnArea:
		return [false, pba_offset]
	else:
		print("ERROR)_parse_map_to_pba>: Invalid map-node BaseType: '%s' " % \
			[_get_node_path_string])
		return [false, pba_offset]

# Encode a map chunks environment
func _encode_map_chunk_environment(map_chunk: EditorMapChunk) -> PackedByteArray:
	var pba: PackedByteArray = []
	var SIZE = 4 + 2 * 2 + 2 # pba.size() + location(x2) + child_count :- set below
	
	# Height Map Stuff (Not used at the moment
#	print("map_chunk.height_map:", map_chunk.height_map)
#	var ctx: CompressedTexture2D = ResourceLoader.load(map_chunk.height_map, \
#		"", ResourceLoader.CACHE_MODE_IGNORE)
#	var img: Image = ctx.get_image()
#	var img_pba: PackedByteArray = img.data["data"]
#	print("img_pba.size():", img_pba.size())
	
#	const TerrainRes: int = 256
#	pba.resize(SIZE + TerrainRes * TerrainRes) Replace below line
	pba.resize(SIZE)
#
#	var i = 0
#	for r in range(0, TerrainRes):
#		for c in range(0, TerrainRes):
#			var idx = (1024 / TerrainRes) * (r * 1024 * 3 + c * 3)
#			pba.encode_u8(SIZE + i, img_pba.decode_u8(idx))
#			i += 1
	
	var child_count: int = 0
#	var pba_offset: int = SIZE + TerrainRes * TerrainRes Replace below line
	var pba_offset: int = SIZE
	for child in map_chunk.get_children():
		var res = _encode_map_child_to_pba(pba, pba_offset, Vector3.ZERO, child)
		var was_parsed: bool = res[0]
		pba_offset = res[1]
		
		if was_parsed:
			child_count += 1
	
	pba.resize(pba_offset)
	pba.encode_u32(0, pba.size())
	pba.encode_u32(4, map_chunk.location.x)
	pba.encode_u32(4 + 2, map_chunk.location.y)
	pba.encode_u16(4 + 2 * 2, child_count)
	return pba

#func encode_kingdom_holdings_list() -> PackedByteArray:
#	var pba: PackedByteArray = PackedByteArray()
#	pba.resize(2)
#
#	var ofs: int = 0
#	pba.encode_s16(ofs, kingdom_holdings.size())
#	ofs += 2
#
#	for prop in kingdom_holdings:
#		var kh: KingdomHolding = prop
#		pba.append_array(kh.encode_to_byte_array())
#
#	return pba

func _set_map_chunk_lumber_trees(_game_world: Object, map_chunk: EditorMapChunk, \
	mc_data: SerializedMapChunk) -> void:
	
	# Lumber trees
	mc_data.lumber_trees = []
	
	for child in map_chunk.get_children():
		if child.visible and child is SpawnArea:
			var spawn_area = child as SpawnArea
			if spawn_area.content == SpawnArea.ContentType.Forest:
				for forest_node in spawn_area.get_children():
					var lumber_pos = spawn_area.position + forest_node.position
					mc_data.lumber_trees.append([object_uid_counter, lumber_pos])
					object_uid_counter += 1
	mc_data.serialize_lumber_trees()

var SerializedMapChunkClass: GDScript = preload("res://map/serialized_map_chunk.gd")

func _load_map_chunk_from_file(_game_world: Object, file_path: String) -> SerializedMapChunk:
	var map_chunk: EditorMapChunk = load(file_path).instantiate() as EditorMapChunk
	
	var mc_data: SerializedMapChunk = SerializedMapChunkClass.new()
	mc_data.chunk_id = 0 # TODO
	mc_data.sz_environment = _encode_map_chunk_environment(map_chunk)
	mc_data.holdings = []
	_set_map_chunk_lumber_trees(_game_world, map_chunk, mc_data)
	
	_game_world.register_chunk(mc_data)
	
	return mc_data

func load_all_maps(game_world: Object) -> int:
#	var kh: KingdomHolding = KingdomHoldingClass.new()
#	kh.holding_uid = object_uid_counter
#	object_uid_counter += 1
#	kh.holding_type = KingdomHolding.HoldingType.Farm
#	kh.area = Rect2i(-14, -14, 12, 12)
#	kingdom_holdings = [kh]
	
	_mc_0_0 = _load_map_chunk_from_file(game_world, "res://map/chunks/ms_0_0.tscn")
	
	return OK
#	map_node = preload("res://map/map_1.tscn").instantiate()
#	map1 = _parse_map_to_pba(world, map_node)

func get_chunk_sz_environment(chunk_id: int) -> PackedByteArray:
	match chunk_id:
		0:
			return _mc_0_0.sz_environment
		_:
			print("ERROR)map_index:get_chunk_sz_environment>: chunk_id=", chunk_id)
			return PackedByteArray()

func get_chunk_sz_lumber_trees(chunk_id: int) -> PackedByteArray:
	match chunk_id:
		0:
			return _mc_0_0.sz_lumber_trees
		_:
			print("ERROR)map_index:get_chunk_sz_lumber_trees>: chunk_id=", chunk_id)
			return PackedByteArray()

func create_holding(_holding_name: String, area: Rect2i) -> int:
	# Ensure holding region does not collide with others
	# Other checks TODO
#	print("KingdomHoldingClass:", KingdomHoldingClass.get_class())
	var kh: KingdomHolding = KingdomHoldingClass.new()
	kh.holding_uid = object_uid_counter
	object_uid_counter += 1
	kh.holding_type = KingdomHolding.HoldingType.Farm
	kh.area = area
	
#	kingdom_holdings.append(kh)
	return OK # Success -- TODO ? create enum of errors
