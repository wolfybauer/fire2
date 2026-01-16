class_name GameManager
extends Node

# Common inverse scale. Calculated as 1.0 / Inverse Scale Factor. 
# Used to help translate properties using Quake Units into Godot Units.
const INVERSE_SCALE: float = 0.03125

var player:PhysicsBody3D
var camera:Camera3D
var tree:SceneTree

#var _floors_above_player:Array[Node3D]
var _lowest_floor:Node3D = null

enum {
	WORLD_LAYER = (1 << 0),
	ACTOR_LAYER = (1 << 1),
	TRIGGER_LAYER = (1 << 2)
}

func _ready() -> void:
	tree = get_tree()

func use_targets(activator: Node, target: String) -> void:
	# Targetnames are really Godot Groups, so we can have multiple entities 
	# share a common "targetname" in Trenchbroom.
	var target_list: Array[Node] = get_tree().get_nodes_in_group(target)
	for targ in target_list:
		var f: String
		# Be careful when specifying a function since we can't pass arguments 
		# to it (without hackarounds of course)
		if 'targetfunc' in activator:
			f = activator.targetfunc
		if f.is_empty():
			f = "use"
		if targ.has_method(f):
			targ.call(f)

func set_targetname(node: Node, targetname: String) -> void:
	if node != null and not targetname.is_empty():
		node.add_to_group(targetname)

# Converts Quake 1 axis to Godot axis
static func id_vec_to_godot_vec(vec: Variant)->Vector3:
	var org: Vector3 = Vector3.ZERO
	if vec is Vector3:
		org = vec
	elif vec is String:
		var arr: PackedFloat64Array = (vec as String).split_floats(" ")
		for i in max(arr.size(), 3):
			org[i] = arr[i]
	return Vector3(org.y, org.z, org.x)


func get_new_lowest_floor():
	#var new_floors:Array[Node3D] = []
	var new_lowest:Node3D = null
	for n in get_tree().get_nodes_in_group('fade_floor'):
		if (n as Node3D).global_position.y < player.global_position.y:
			continue
		#new_floors.append(n)
		if new_lowest == null or (n as Node3D).global_position.y < new_lowest.global_position.y:
			new_lowest = n
	if new_lowest != _lowest_floor:
		_lowest_floor = new_lowest
		#_floors_above_player = new_floors
		return true
	return false

#func check_fade_obj(n, )

func _process(_delta: float) -> void:
	if not player or not camera:
		return
	FadeWall3D.check_fade_walls(tree, player, camera, 2.0, 5.0, 0.25)
	for n in get_tree().get_nodes_in_group('fade_wall'):
		n.check_fade(player, camera, 3.0)
	for n in get_tree().get_nodes_in_group('fade_floor'):
		n.check_fade(player, camera)

	get_new_lowest_floor()
	for n in get_tree().get_nodes_in_group('fade_obj'):
		if n == player: continue
		if _lowest_floor == null:
			n.visible = true
			continue
		if (n as Node3D).global_position.y > _lowest_floor.global_position.y:
			n.visible = false
		else:
			n.visible = true
