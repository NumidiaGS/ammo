extends Node3D

class_name GameWorld

var chunks: Array

#var maps: Dictionary = {}

#var _mutex: Mutex

#var kingdom_node: Node3D
#func set_object_map(node: Node3D) -> void:
#	if kingdom_node:
#		print("WARNING removing existing kingdom node")
#		remove_child(kingdom_node)
#		kingdom_node.call_deferred('free')
#
#	kingdom_node = node
#	add_child(kingdom_node)
#var static_objects: Array[CollisionShape3D]

var _temp_chunk_o_trees: bool = false

func reset_chunk_trees(_chunk_location: Vector2i, lumber_tree_list: Array) -> void:
	if _temp_chunk_o_trees:
		print("TODO -- trees already set")
		return
	for lt in lumber_tree_list:
		add_child(lt)
	
	_temp_chunk_o_trees = true

func add_chunk(map_chunk: MapChunk) -> void:
	for item in chunks:
		var mc: MapChunk = item as MapChunk
		if mc.location == map_chunk.location:
			print("Error map node has already been set for chunk_index:", map_chunk.chunk_id)
			return
	
	chunks.append(map_chunk)
	add_child(map_chunk)
	
	# TODO
#	for child in node.get_children():
#		var map_item: MapObject = child
#		if not map_item:
#			print("Warning: map-child-node isn't MapObject")
#			continue
#		if map_item.object_type != MapObject.ObjectType.StaticSolid and \
#			map_item.object_type != MapObject.ObjectType.StaticInteractable:
##			print("NotYetImplemented")
#			continue
#		for grandchild in map_item.get_children():
#			if grandchild is CollisionShape3D:
#				static_objects.append(grandchild)
#define NUMDIM	3
#define RIGHT	0
#define LEFT	1
#define MIDDLE	2

#func HitBoundingBox(minB: Vector3, maxB: Vector3, origin: Vector3, dir: Vector3, coord: Vector3) \
#	-> bool:
#	var inside = true
#
#	var quadrant = [false, false, false];
#	var i: int
#	var whichPlane: int
#	var maxT: Vector3
#	var candidate_plane
#	register int i;
#	int whichPlane;
#	double maxT[NUMDIM];
#	double candidatePlane[NUMDIM];
#
#	/* Find candidate planes; this loop can be avoided if
#   	rays cast all from the eye(assume perpsective view) */
#	for (i=0; i<NUMDIM; i++)
#		if(origin[i] < minB[i]) {
#			quadrant[i] = LEFT;
#			candidatePlane[i] = minB[i];
#			inside = FALSE;
#		}else if (origin[i] > maxB[i]) {
#			quadrant[i] = RIGHT;
#			candidatePlane[i] = maxB[i];
#			inside = FALSE;
#		}else	{
#			quadrant[i] = MIDDLE;
#		}
#
#	/* Ray origin inside bounding box */
#	if(inside)	{
#		coord = origin;
#		return (TRUE);
#	}
#
#
#	/* Calculate T distances to candidate planes */
#	for (i = 0; i < NUMDIM; i++)
#		if (quadrant[i] != MIDDLE && dir[i] !=0.)
#			maxT[i] = (candidatePlane[i]-origin[i]) / dir[i];
#		else
#			maxT[i] = -1.;
#
#	/* Get largest of the maxT's for final choice of intersection */
#	whichPlane = 0;
#	for (i = 1; i < NUMDIM; i++)
#		if (maxT[whichPlane] < maxT[i])
#			whichPlane = i;
#
#	/* Check final candidate actually inside box */
#	if (maxT[whichPlane] < 0.) return (FALSE);
#	for (i = 0; i < NUMDIM; i++)
#		if (whichPlane != i) {
#			coord[i] = origin[i] + maxT[whichPlane] *dir[i];
#			if (coord[i] < minB[i] || coord[i] > maxB[i])
#				return (FALSE);
#		} else {
#			coord[i] = candidatePlane[i];
#		}
#	return (TRUE);				/* ray hits box */
#}
func _ray_intersects_sphere(centre: Vector3, radius: float, ray_pos: Vector3, ray_dir: Vector3) \
	-> float:
	var m: Vector3 = ray_pos - centre; 
	var b: float = m.dot(ray_dir)
	var c: float = m.dot(m) - radius * radius

	# Exit if r’s origin outside s (c > 0) and r pointing away from s (b > 0) 
	if c > 0.0 and b > 0.0:
		return -1.0
	
	var discr: float = b * b - c
	
	# A negative discriminant corresponds to ray missing sphere
	if discr < 0.0:
		return -1.0
	
	# Ray now found to intersect sphere, compute smallest t value of intersection
	var t = -b - sqrt(discr)
	
	# If t is negative, ray started inside sphere so clamp t to zero
	if t < 0.0:
		t = 0.0
	return t

func _ray_intersects_box(box_min: Vector3, box_max: Vector3, ray_pos: Vector3, ray_dir: Vector3) \
	-> bool:
	var tx1: float = (box_min.x - ray_pos.x) * (1.0 / ray_dir.x)
	var tx2: float = (box_max.x - ray_pos.x) * (1.0 / ray_dir.x)
	var tmin: float = min(tx1, tx2)
	var tmax: float = max(tx1, tx2)
	
	var ty1: float = (box_min.y - ray_pos.y) * (1.0 / ray_dir.y)
	var ty2: float = (box_max.y - ray_pos.y) * (1.0 / ray_dir.y)
	tmin = max(tmin, min(ty1, ty2))
	tmax = min(tmax, max(ty1, ty2))
	
	var tz1: float = (box_min.z - ray_pos.z) * (1.0 / ray_dir.z)
	var tz2: float = (box_max.z - ray_pos.z) * (1.0 / ray_dir.z)
	tmin = max(tmin, min(tz1, tz2))
	tmax = min(tmax, max(tz1, tz2))
	
	return tmax >= max(tmin, 0.0)

func get_picking_collision(ray_pos: Vector3, ray_dir: Vector3, max_dist: float) -> MapObject:
	var ray_end = ray_pos + ray_dir * max_dist
	
	print("ray:", ray_pos, "|", ray_dir)
	for chunk in chunks:
		print("chunk-bounds:", chunk.bounds)
		var intersects = chunk.bounds.intersects_segment(ray_pos, ray_end)
		print("intersects:", intersects)
		if intersects:
			continue
		
		
#	for co in static_objects:
#		if co.shape is BoxShape3D:
#			# ATM assume it is axis aligned
#			var box: BoxShape3D = co.shape
#			var box_min: Vector3 = co.get_parent_node_3d().position + co.position - box.size
#			var box_max: Vector3 = co.get_parent_node_3d().position + co.position + box.size
#			if _ray_intersects_box(box_min, box_max, ray_pos, ray_dir):
##				print("player_ray_intersects_box:", box_min, box_max, ray_pos, ray_dir)
#				return co.get_parent_node_3d()
#		elif co.shape is SphereShape3D:
#			var sphere: SphereShape3D = co.shape
#			var sphere_centre: Vector3 = co.get_parent_node_3d().position + co.position
#			var dist: float = _ray_intersects_sphere(sphere_centre, sphere.radius, ray_pos, ray_dir)
##			print("player_ray_intersects_sphere:", sphere_centre, sphere.radius, ray_pos, \
##				ray_dir)
#			if dist >= 0.0:
##				print("player_ray_intersects_sphere:", sphere_centre, sphere.radius, ray_pos, \
##					ray_dir)
#				return co.get_parent_node_3d()
#		else:
#			print("Warning Unknown static object shape type:'%s'" % co.shape.get_class())
	
	return null
