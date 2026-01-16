class_name Glass
extends StaticBody3D

@onready var destronoi:DestronoiGD = DestronoiGD.new()
const GLASS_MATERIAL = preload("res://addons/glass/glass_material.tres")

@export var health:float = 1.0

@export var blur_enable:bool = true
@export var glass_color:Color = Color(1.0, 1.0, 1.0, 0.0)
@export var blur_radius:int = 25
@export_range(0.1, 1.0, 0.1) var blur_strength = 1.0
@export_range(0.1, 1.0, 0.1) var bright = 0.2

var mesh:MeshInstance3D
var glass_mat:ShaderMaterial

func _ready() -> void:
	glass_mat = GLASS_MATERIAL.duplicate()
	glass_mat.set_shader_parameter('blur_enable', blur_enable)
	glass_mat.set_shader_parameter('glass_color', glass_color)
	glass_mat.set_shader_parameter('blur_radius', blur_radius)
	glass_mat.set_shader_parameter('blur_strength', blur_strength)
	glass_mat.set_shader_parameter('bright', bright)
	
	mesh = get_child(0)
	#mesh.mesh = mesh.mesh.duplicate() # DEBUG ONLY. REMOVE!!
	mesh.mesh.surface_set_material(0, glass_mat)
	#mesh.material_overlay = glass_mat
	# TODO: add normal
	
	destronoi.tree_height = 5
	destronoi.persistence = 1.0
	
	add_child(destronoi)
	add_to_group('fade_obj')
	
func apply_damage(damage:int, _direction:Vector3=Vector3.ZERO):
	health -= damage
	if health <= 0:
		destronoi.destroy(5.0,damage*_direction)
