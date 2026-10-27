extends Node3D
## QA-only camera depth capture; not used by the playable entry scene.

@export var player_world_z: float = 3.5


func _ready() -> void:
	var arena := $Arena as Node3D
	var player := arena.get_node("Player") as CharacterBody3D
	player.global_position = Vector3(0.0, 0.0, player_world_z)
	player.call("set_facing_direction", Vector3(0.0, 0.0, -1.0 if player_world_z < 0.0 else 1.0))
