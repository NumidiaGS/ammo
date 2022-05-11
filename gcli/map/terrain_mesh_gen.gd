# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, March 2022

extends Object

class_name TerrainMeshGen

const TerrainRes: int = 256
	
# Called when the node enters the scene tree for the first time.
static func create_mesh(pba: PackedByteArray, pba_offset: int) -> MeshInstance3D:
	var st = SurfaceTool.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var uv_step = 1.0 / (TerrainRes - 1)
	
	var scale: float = 4.0
	var scalar_offset: float = -scale * TerrainRes * 0.5
	
	for y in range(0, TerrainRes):
		for x in range(0, TerrainRes):
			# Prepare attributes for add_vertex.
#			st.set_normal(Vector3(1, 1, 0).normalized())
			st.set_uv(Vector2(uv_step * x, uv_step * y))
			# Call last for each vertex, adds the above attributes.
#			print("v:%d,%d,%d,%d" % [ uv_step * x, uv_step * y, x, y ])
#			print("h[%d,%d=%d]=%d %d %d" % [x, y, idx, \
#				pba[idx], pba[idx + 1], pba[idx + 2]])
			st.add_vertex(Vector3(scalar_offset + x * 4.0, \
				-41.5 + 196.0 * float(pba.decode_u8(pba_offset + y * TerrainRes + x)) / 255.0, \
				scalar_offset + y * 4.0))
	
	# Have to provide vertices as a multiple of 3 (Yes, even though we index them, and it will
	#  only count if those vertices are used in the index list too, so the following bloat to fit
	#  with the creation model...
	if (TerrainRes * TerrainRes) % 3 != 0:
		st.add_vertex(Vector3(scalar_offset, 0.0, scalar_offset))
		st.add_index(0)
		st.add_index(1)
		st.add_index(TerrainRes * TerrainRes)
		if (TerrainRes * TerrainRes) % 3 == 1:
			st.add_vertex(Vector3(scalar_offset, 0.0, scalar_offset))
			st.add_index(0)
			st.add_index(1)
			st.add_index(TerrainRes * TerrainRes + 1)
	
	# Indices
	for y in range(0, TerrainRes - 1):
		for x in range(0, TerrainRes - 1):
			st.add_index(y * TerrainRes + x)
			st.add_index(y * TerrainRes + x + 1)
			st.add_index((y + 1) * TerrainRes + x)
			
			st.add_index((y + 1) * TerrainRes + x)
			st.add_index(y * TerrainRes + x + 1)
			st.add_index((y + 1) * TerrainRes + x + 1)
	
	st.generate_normals()
	
	# Commit to a mesh.
	var mesh = st.commit()
	
	var mesh3D: MeshInstance3D = MeshInstance3D.new()
	mesh3D.mesh = mesh
	
	var tex = preload("res://map/assets/green_grid/green_grid.tres")
	mesh3D.mesh.surface_set_material(0, tex)
	
	return mesh3D
