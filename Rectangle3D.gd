class_name Rectangle3D
extends MeshInstance3D

@export var bottomLeft : Vector3
@export var rightward : Vector3
@export var upward : Vector3
@export var rect_color := Color(0.5, 0.8, 1.0, 0.3)
var normal : Vector3
@export var diagonal : float
var upwardLengthSquared : float
var rightwardLengthSquared : float

func _ready() -> void:
	print("MR DEBUG Rectangle3D()",bottomLeft,rightward,upward)
	var v0 = bottomLeft
	var v1 = bottomLeft + rightward
	var v2 = v1 + upward
	var v3 = bottomLeft + upward
	normal = rightward.cross(upward)
	rightwardLengthSquared = rightward.length_squared()
	upwardLengthSquared = upward.length_squared()
	diagonal = (rightward+upward).length()

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = rect_color

	var imm_mesh = ImmediateMesh.new()
	imm_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)

	imm_mesh.surface_add_vertex(v0)
	imm_mesh.surface_add_vertex(v1)
	imm_mesh.surface_add_vertex(v2)

	imm_mesh.surface_add_vertex(v0)
	imm_mesh.surface_add_vertex(v2)
	imm_mesh.surface_add_vertex(v3)

	imm_mesh.surface_end()
	
	self.mesh = imm_mesh	

func intersectRay(base: Vector3, dir: Vector3) -> Array:
	# returns [position,distance,[x,y]] or []
	var normal_dot_dir := normal.dot(dir)
	if is_zero_approx(normal_dot_dir):
		return []
	var t := (bottomLeft - base).dot(normal) / normal_dot_dir
	if t < 0:
		return []
	var pos := base + t * dir
	var delta := pos - bottomLeft
	var x := delta.dot(rightward)/rightwardLengthSquared
	var y := delta.dot(upward)/upwardLengthSquared
	return [pos, t*dir.length(), Vector2(x,y)]
	
	
