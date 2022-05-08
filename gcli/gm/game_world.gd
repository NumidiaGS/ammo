extends Node3D

class_name GameWorld

var space_rid: RID
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
	
	space_rid = PhysicsServer3D.space_create()
	
	for child in map_chunk.get_children():
		var mo: MapObject = child as MapObject
		if mo and mo.object_type == MapObject.ObjectType.StaticInteractable:
			var body_created: bool = false
			var body_rid: RID
			
			for grand_child in mo.get_children():
				var co: CollisionShape3D = grand_child as CollisionShape3D
				if not co:
					continue
				
				if body_created == false:
					body_rid = PhysicsServer3D.body_create()
					PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
					body_created = true
				
				var shape_rid: RID
				if co.shape is BoxShape3D:
					shape_rid = PhysicsServer3D.box_shape_create()
					PhysicsServer3D.shape_set_data(shape_rid, (co.shape as BoxShape3D).size)
					PhysicsServer3D.body_add_shape(body_rid, shape_rid, co.transform)
					print("--added box:", shape_rid)
				elif co.shape is SphereShape3D:
					shape_rid = PhysicsServer3D.sphere_shape_create()
					PhysicsServer3D.shape_set_data(shape_rid, (co.shape as SphereShape3D).radius)
					PhysicsServer3D.body_add_shape(body_rid, shape_rid, co.transform)
					print("--added sphere:", shape_rid)
				else:
					print("dont know what shape TODO")
			
			if body_created:
				print("body_rid:", body_rid)
				PhysicsServer3D.body_set_space(body_rid, space_rid)
				PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, \
					mo.transform)
				PhysicsServer3D.body_set_ray_pickable(body_rid, true)
			else:
				print("no shapes found for static-interactable!:", mo.resource_id)
	
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

func _intersect_map_object(ray_pos: Vector3, ray_dir: Vector3, mo: MapObject) -> float:
	var nearest_intersect = -1.0
	for element in mo.get_children():
		var cs = element as CollisionShape3D
		if cs:
			if cs.shape is BoxShape3D:
				# ATM assume it is axis aligned
				var box: BoxShape3D = cs.shape
				var box_min: Vector3 = cs.get_parent_node_3d().position + cs.position - box.size
				var box_max: Vector3 = cs.get_parent_node_3d().position + cs.position + box.size
				var dist = _ray_intersects_box(box_min, box_max, ray_pos, ray_dir)
				if nearest_intersect < 0 or dist >= 0.0:
					nearest_intersect = dist
			elif cs.shape is SphereShape3D:
				var sphere: SphereShape3D = cs.shape
				var sphere_centre: Vector3 = cs.get_parent_node_3d().position + cs.position
				var dist: float = _ray_intersects_sphere(sphere_centre, sphere.radius, ray_pos, \
					ray_dir)
				if dist >= 0.0 and (nearest_intersect < 0 or dist < nearest_intersect):
					nearest_intersect = dist
#			print("player_ray_intersects_sphere:", sphere_centre, sphere.radius, ray_pos, \
#				ray_dir)
#				print("player_ray_intersects_sphere:", sphere_centre, sphere.radius, ray_pos, \
#					ray_dir)
			else:
				print("Warning Unknown static object shape type:'%s'" % cs.shape.get_class())
	return nearest_intersect

func get_picking_collision(ray_pos: Vector3, ray_dir: Vector3, max_dist: float) -> MapObject:
	var ray_end = ray_pos + ray_dir * max_dist
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = ray_pos
	query.to = ray_pos + ray_dir * max_dist
	
	var result = PhysicsServer3D.space_get_direct_state(space_rid).intersect_ray(query)
	print("result:", result)
	return
	
	
	print("ray:", ray_pos, "|", ray_dir)
	var nearest_dist: float = -1.0
	var nearest_intersection: MapObject = null
#	for chunk in chunks:
#		print("chunk-bounds:", chunk.bounds)
#		var intersects = chunk.bounds.intersects_segment(ray_pos, ray_end)
#		print("intersects:", intersects)
#		if intersects:
#			for child in chunk.get_children():
#				var mo: MapObject = child as MapObject
#				if mo and mo.object_type == MapObject.ObjectType.StaticInteractable:
#					var dist: float = _intersect_map_object(ray_pos, ray_dir, child)
#					if dist >= 0.0 and (nearest_dist < 0.0 or dist < nearest_dist):
#						nearest_dist = dist
#						nearest_intersection = child
	
	return nearest_intersection
