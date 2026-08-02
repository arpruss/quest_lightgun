extends Node3D

const MATERIAL = preload("res://assets/cross-grid-material.tres")

@onready var static_body: StaticBody3D = $StaticBody3D
const epsilon := 1e-6

var mesh_instance: MeshInstance3D

func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	_deferred_setup_scene.call_deferred(entity)
	
func _deferred_setup_scene(entity: OpenXRFbSpatialEntity) -> void:	
	if entity.get_semantic_labels()[0] != "screen":
		return
		
	var collision_shape = entity.create_collision_shape()
	if collision_shape:
		static_body.add_child(collision_shape)

	print("MR DEBUG: have screen")

	mesh_instance = entity.create_mesh_instance()
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.1, 0.1, 0.1)
		mesh_instance.mesh = box_mesh
	else:
		print("MR DEBUG has mesh_instance")
		
	var rectangles := _screen_rectangles(entity)
	print("MR DEBUG rects ",rectangles)
	for r in rectangles:
		print("MR DEBUG add rectangle",r)
		get_tree().call_group("main_group", "addScreen", r)

#	var material: StandardMaterial3D = MATERIAL.duplicate()
#	mesh_instance.set_surface_override_material(0, material)

#	add_child(mesh_instance)
	
func _screen_rectangles(entity: OpenXRFbSpatialEntity) -> Array:
	var bb := entity.get_bounding_box_3d()
	var axes := []
	# sort the axes to have: width,height,depth
	if bb.size[0] <= bb.size[1]:
		if bb.size[1] <= bb.size[2]:
			axes = [2,1,0]
		elif bb.size[0] <= bb.size[2]:
			axes = [1,2,0]
		else:
			axes = [1,0,2]
	else:
		if bb.size[0] <= bb.size[2]:
			axes = [2,0,1]
		elif bb.size[2] <= bb.size[1]:
			axes = [0,1,2]
		else:
			axes = [0,2,1]

	var upSign := 1
	var upVector := Vector3()
	if global_transform.basis[axes[1]][1] < 0:
		upSign = -1
	upVector[axes[1]] = upSign * bb.size[axes[1]]
	const outSign := -1
	var rightSign := upSign * outSign
	var rightVector := Vector3()
	if (axes[1]+1) % 3 == axes[2]:
		rightSign = -rightSign 
	rightVector[axes[0]] = rightSign * bb.size[axes[0]]
	print("MR DEBUG axes",axes," up ",upVector," right ",rightVector)
	
	var frontBottomLeft := Vector3()
	var frontTopRight := Vector3()
	var backBottomLeft := Vector3()
	var backTopRight := Vector3()
	if outSign > 0:
		frontBottomLeft[axes[2]] = bb.end[axes[2]]
		backBottomLeft[axes[2]] = bb.position[axes[2]]
	else:
		frontBottomLeft[axes[2]] = bb.position[axes[2]]
		backBottomLeft[axes[2]] = bb.end[axes[2]]
	if upSign > 0:
		frontBottomLeft[axes[1]] = bb.position[axes[1]]
		backBottomLeft[axes[1]] = bb.position[axes[1]]
	else:
		frontBottomLeft[axes[1]] = bb.end[axes[1]]
		backBottomLeft[axes[1]] = bb.end[axes[1]]
	if rightSign > 0:
		frontBottomLeft[axes[0]] = bb.position[axes[0]]
		backBottomLeft[axes[0]] = bb.end[axes[0]]
	else:
		frontBottomLeft[axes[0]] = bb.end[axes[0]]
		backBottomLeft[axes[0]] = bb.position[axes[0]]
		
	frontBottomLeft = global_transform * frontBottomLeft
	backBottomLeft = global_transform * backBottomLeft
	var rot := global_transform.basis.orthonormalized()
	#upVector = rot * upVector
	#rightVector = rot * rightVector
	upVector = global_transform * upVector - global_transform * Vector3(0,0,0)
	rightVector = global_transform * rightVector - global_transform * Vector3(0,0,0)
		
	if abs(bb.size[axes[2]]) < epsilon:
		return [[frontBottomLeft,rightVector,upVector],]
	else:
		return [[frontBottomLeft,rightVector,upVector],[backBottomLeft,-rightVector,upVector]]
	
func _get_color_for_label(semantic_label) -> Color:
	match semantic_label:
		"ceiling", "floor":
			return Color(0.0, 0.0, 0.0, 1.0)
		"wall_face", "invisible_wall_face":
			return Color(0.0, 0.0, 1.0, 1.0)
		"window_frame", "door_frame":
			return Color(1.0, 0.0, 0.0, 1.0)
		"couch", "table", "bed", "lamp", "plant", "screen", "storage":
			return Color(0.0, 1.0, 0.0, 1.0)

	return Color(1.0, 1.0, 1.0, 1.0)
