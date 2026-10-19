class_name PlayerCamera
extends Node3D

## A simple camera rig that keeps a fixed distance above and behind the player,
## with a smooth follow for a nicer feel.

## Path to the node to follow. Point it at the player in the inspector.
@export var target_path: NodePath
## The node to follow (resolved from target_path once we enter the tree).
@onready var target: Node3D = get_node(target_path)
## Where the camera sits relative to the player.
@export var offset := Vector3(0.0, 18.0, 14.0)
## Higher = follows faster (snappier).
@export var follow_speed := 5.0

func _ready() -> void:
	# Start already at the right place so the very first frame looks correct.
	global_position = target.global_position + offset

func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Slide toward the wanted position smoothly. The "1 - exp(...)" formula
	# makes the movement frame-rate independent, so the feel is the same no
	# matter how fast the game runs.
	var wanted_position := target.global_position + offset
	global_position = global_position.lerp(wanted_position, 1.0 - exp(-follow_speed * delta))

	# Point the camera at the player so they stay in the middle of the screen.
	look_at(target.global_position, Vector3.UP)