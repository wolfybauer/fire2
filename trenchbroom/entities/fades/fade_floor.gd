class_name FadeFloor
extends StaticBody3D

@export var fade_speed := 5.0
@export var min_alpha := 0.15

const FADE_MATERIAL = preload("res://trenchbroom/shaders/fade_material.tres")

const PRIORITY:int = 0

var target_fade := 1.0
var fade := 1.0

var aabb_min:Vector2
var aabb_max:Vector2
var center2d:Vector2
var floor_y:float

@onready var mesh:MeshInstance3D
@onready var mat:ShaderMaterial


func _ready():
	#return
	add_to_group('fade_floor')
	mesh = get_child(0)
	mat = FADE_MATERIAL.duplicate()
	mat.render_priority = PRIORITY
	var old:StandardMaterial3D = mesh.mesh.surface_get_material(0)
	mat.set_shader_parameter('_albedo', old.albedo_texture)
	#mesh.set_surface_override_material(0, mat)
	_precompute_bounds()

func _physics_process(delta):
	if not is_equal_approx(fade, target_fade):
		fade = lerp(fade, target_fade, fade_speed * delta)
		mat.set_shader_parameter('opacity', fade)
		# print('fading! ', fade)

func check_fade(player:Node3D, camera:Camera3D):
	
	if player.global_position.y+2 < global_position.y:
		target_fade = min_alpha
		visible = false
		return
	visible = true
	if (global_transform.origin.y + floor_y) < player.global_position.y:
		target_fade = 1.0
		return
	
	var ply2 := Vector2(player.global_position.x, player.global_position.z)

	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var cam2 := Vector2(camera.global_position.x, camera.global_position.z)

		# 1. 2D intersection
		if not _segment_hits_aabb(cam2, ply2):
			target_fade = 1.0
			return

		# 2. vertical relation
		if camera.global_position.y <= floor_y:
			target_fade = 1.0
			return

		if player.global_position.y >= floor_y:
			target_fade = 1.0
			return

		target_fade = min_alpha

	elif camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		# 0. projection direction in XZ
		var proj3 := -camera.global_transform.basis.z
		proj3.y = 0.0
		proj3 = proj3.normalized()
		var dir2 := Vector2(proj3.x, proj3.z)

		# 1. check if floor is *between* camera and player
		# if dot < 0 → floor is behind player toward camera → NO fade
		var fp := ply2 - Vector2(center2d.x, center2d.y)
		if fp.dot(dir2) < 0.0:
			target_fade = 1.0
			return

		# 2. infinite line through player
		var A := ply2 - dir2 * 9999.0
		var B := ply2 + dir2 * 9999.0

		if not _segment_hits_aabb(A, B):
			target_fade = 1.0
			return

		# 3. vertical relation
		if camera.global_position.y <= floor_y:
			target_fade = 1.0
			return

		if player.global_position.y >= floor_y:
			target_fade = 1.0
			return

		target_fade = min_alpha


func _precompute_bounds():
	var arrays = mesh.mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX]
	var xf = mesh.global_transform

	var minx = INF
	var maxx = -INF
	var minz = INF
	var maxz = -INF
	var miny = INF

	for v in verts:
		var w:Vector3 = xf.origin + xf.basis * v

		minx = min(minx, w.x)
		maxx = max(maxx, w.x)
		minz = min(minz, w.z)
		maxz = max(maxz, w.z)
		miny = min(miny, w.y)  # all floor verts share the same y

	center2d = (aabb_min + aabb_max) * 0.5
	aabb_min = Vector2(minx, minz)
	aabb_max = Vector2(maxx, maxz)
	floor_y = miny

func _point_in_aabb(p:Vector2) -> bool:
	return (
		p.x >= aabb_min.x and p.x <= aabb_max.x and
		p.y >= aabb_min.y and p.y <= aabb_max.y
	)

func _seg_seg(p1:Vector2, p2:Vector2, p3:Vector2, p4:Vector2) -> bool:
	var d1 = p2 - p1
	var d2 = p4 - p3

	var denom = d1.cross(d2)
	if abs(denom) < 0.000001:
		return false  # parallel or collinear (rare for walls)

	var t = (p3 - p1).cross(d2) / denom
	var u = (p3 - p1).cross(d1) / denom

	return (t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0)


func _segment_hits_aabb(cam2:Vector2, ply2:Vector2) -> bool:
	# 1) if either endpoint is inside the box
	if _point_in_aabb(cam2) or _point_in_aabb(ply2):
		return true

	# 2) check intersection with each AABB edge
	var minx = aabb_min.x
	var maxx = aabb_max.x
	var miny = aabb_min.y
	var maxy = aabb_max.y

	# 4 edges = 4 line segments
	# left   edge: (minx, miny) -> (minx, maxy)
	# right  edge: (maxx, miny) -> (maxx, maxy)
	# bottom edge: (minx, miny) -> (maxx, miny)
	# top    edge: (minx, maxy) -> (maxx, maxy)

	if _seg_seg(cam2, ply2, Vector2(minx, miny), Vector2(minx, maxy)): return true
	if _seg_seg(cam2, ply2, Vector2(maxx, miny), Vector2(maxx, maxy)): return true
	if _seg_seg(cam2, ply2, Vector2(minx, miny), Vector2(maxx, miny)): return true
	if _seg_seg(cam2, ply2, Vector2(minx, maxy), Vector2(maxx, maxy)): return true

	return false
