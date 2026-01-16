class_name FadeWall
extends StaticBody3D

@export var fade_speed := 5.0
@export var min_alpha := 0.25

const FADE_MATERIAL = preload("res://trenchbroom/shaders/fade_material.tres")

const PRIORITY:int = 1

var target_fade := 1.0
var fade := 1.0

var aabb_min:Vector2
var aabb_max:Vector2
var center2d:Vector2
var wall_height:float
var wall_normal:Vector2
var dist_to_player:float

@onready var mesh:MeshInstance3D
@onready var mat:ShaderMaterial

func _ready():
	if Engine.is_editor_hint():
		return
	add_to_group('fade_wall')
	mesh = get_child(0)
	mat = FADE_MATERIAL.duplicate()
	mat.render_priority = PRIORITY
	var old:StandardMaterial3D = mesh.mesh.surface_get_material(0)
	mat.set_shader_parameter('_albedo', old.albedo_texture)
	mesh.set_surface_override_material(0, mat)
	_precompute_bounds()

func _physics_process(delta):
	if not is_equal_approx(fade, target_fade):
		fade = lerp(fade, target_fade, fade_speed * delta)
		mat.set_shader_parameter('opacity', fade)
		# print('fading! ', fade)

func check_fade(player:Node3D, camera:Camera3D, max_dist:float=3.0):
	if player.global_position.y+2 < global_position.y:
		target_fade = min_alpha
		visible = false
		return
	visible = true
	if (global_transform.origin.y + wall_height) < player.global_position.y:
		target_fade = 1.0
		return
	
	var ply2 := Vector2(player.global_position.x, player.global_position.z)

	if max_dist > 0.0 and wall_normal != Vector2.ZERO:
		dist_to_player = (ply2 - center2d).dot(wall_normal)
		if abs(dist_to_player) > max_dist:
			target_fade = 1.0
			return

	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var cam2 := Vector2(camera.global_position.x, camera.global_position.z)

		# early reject
		if _projected_outside(cam2, ply2):
			target_fade = 1.0
			return

		if _segment_hits_aabb(cam2, ply2):
			target_fade = min_alpha
		else:
			target_fade = 1.0

	elif camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var forward := -camera.global_transform.basis.z
		forward.y = 0.0
		var yaw := atan2(forward.x, forward.z)

		# pillar? no back/front test
		if wall_normal != Vector2.ZERO:
			var rel_normal := wall_normal.rotated(-yaw)
			var wp := ply2 - center2d

			# player is in front of wall never fade
			if wp.dot(rel_normal.rotated(camera.rotation.y)) <= 0.0:
				target_fade = 1.0
				return

		# infinite ray in camera forward direction
		var proj_dir := Vector2(forward.x, forward.z).normalized()
		var A := ply2 - proj_dir * 9999.0
		var B := ply2 + proj_dir * 9999.0

		target_fade = min_alpha if _segment_hits_aabb(A, B) else 1.0

func _precompute_bounds():
	# get the mesh verts and transform them into world space
	var arrays = mesh.mesh.surface_get_arrays(0)
	var arr = arrays[Mesh.ARRAY_VERTEX]
	var xf = mesh.global_transform

	var minx = INF
	var maxx = -INF
	var minz = INF
	var maxz = -INF
	var maxy = -INF

	for v in arr:
		var w = xf.origin + xf.basis * v
		minx = min(minx, w.x)
		maxx = max(maxx, w.x)
		minz = min(minz, w.z)
		maxz = max(maxz, w.z)
		maxy = max(maxy, w.y)

	aabb_min = Vector2(minx, minz)
	aabb_max = Vector2(maxx, maxz)
	center2d = (aabb_min + aabb_max) * 0.5
	wall_height = maxy - global_position.y

	var dx = abs(aabb_max.x - aabb_min.x)
	var dz = abs(aabb_max.y - aabb_min.y)

	if abs(dx - dz) < 0.1:
		wall_normal = Vector2.ZERO  # pillar / square → no reliable normal

	if dx > dz:
		wall_normal = Vector2(0, 1)   # facing ±Z
	else:
		wall_normal = Vector2(1, 0)   # facing ±X


# --- helper: 2d AABB vs camera→player segment ---

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

# quick reject: wall not between camera and player on the main axis
func _projected_outside(cam2:Vector2, ply2:Vector2) -> bool:
	var v = ply2 - cam2
	var w = center2d - cam2
	# if dot signs differ or wall lies further than player → no occlusion
	return (v.dot(w) <= 0 or w.length() > v.length())
