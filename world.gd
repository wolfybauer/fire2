extends Node3D

@onready var player: Player = $Player
@onready var camera_3d: Camera3D = $Player/CameraPivot/Camera3D

var tree:SceneTree

func _ready() -> void:
	tree = get_tree()
	
func _process(_delta: float) -> void:
	FadeWall3D.check_fade_walls(tree, player, camera_3d, 5.0, 5.0, 0.25)
	FadeFloor3D.check_fade_floors(tree, player, 2.0)
	FadeFloor3D.check_fade_objects(tree, player, 2.5)
