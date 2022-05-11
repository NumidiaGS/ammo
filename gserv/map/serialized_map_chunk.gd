# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, March 2022

extends RefCounted

class_name SerializedMapChunk

var chunk_id: int

# Terrain height map and non-interactable geometry
var sz_environment: PackedByteArray

# Kingdom Holdings
var holdings: Array

# General interactable items / objects in the world
var items: PackedByteArray
var items_hash: int

# Lumber Trees
var lumber_trees: Array
var sz_lumber_trees: PackedByteArray
var sz_lumber_trees_hash: int

func serialize_lumber_trees() -> void:
	sz_lumber_trees = PackedByteArray()
	
	var new_hash: int = 13
	
	const LumberTreeByteSize: int = (4 + 4 * 3)
	sz_lumber_trees.resize(4 + 4 + lumber_trees.size() * LumberTreeByteSize)
	
	var pba_offset: int = 0
	sz_lumber_trees.encode_u32(pba_offset, chunk_id)
	pba_offset += 4
	
	sz_lumber_trees.encode_u32(pba_offset, lumber_trees.size())
	pba_offset += 4
	
	for lta in lumber_trees:
		new_hash = new_hash * 53 + 79 + lta[0]
		
		sz_lumber_trees.encode_u32(pba_offset, lta[0])
		var lumber_pos = lta[1]
		sz_lumber_trees.encode_float(pba_offset + 4, lumber_pos.x)
		sz_lumber_trees.encode_float(pba_offset + 8, lumber_pos.y)
		sz_lumber_trees.encode_float(pba_offset + 12, lumber_pos.z)
		pba_offset += LumberTreeByteSize
	
	sz_lumber_trees_hash = new_hash
