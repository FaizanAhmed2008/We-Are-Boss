class_name Player
extends CharacterBody3D

## Top-down movement for the player character.
## All values can be tweaked in the Godot inspector.

## Movement speed in meters per second.
@export var move_speed: float = 8.0
## How fast the player turns to face the direction it walks in.
## Set to 0 to turn instantly instead of smoothly.
@export var turn_speed: float = 10.0

## Total health the player has. Reaching 0 means death ("You Died").
@export var max_health: float = 100.0
## Current health. Enemies call take_damage() to reduce this.
var health: float
## Set once health hits 0: stops movement and shows the death message.
var is_dead: bool = false

## Combat settings for the player's basic melee attack.

## How close a target must be (in metres) for a swing to hit it.
@export var attack_range: float = 2.5
## Health removed from each target inside range per swing.
@export var attack_damage: float = 25.0
## Seconds between swings. Smaller = faster swings.
@export var attack_cooldown: float = 0.6
## Group whose members are valid attack targets (enemies go in here).
@export var attack_target_group: StringName = &"enemies"

## Time left until the player may swing again (0 = ready).
var _attack_timer: float = 0.0

@onready var _died_label: Label = $DeathUI/DiedLabel

func _ready() -> void:
	# Current health always starts at the maximum.
	health = max_health
	_died_label.visible = false

func _physics_process(delta: float) -> void:
	# Once dead we stop moving and ignore input.
	if is_dead:
		velocity = Vector3.ZERO
		return

	# get_axis(negative_action, positive_action) returns -1..1.
	# Pressing W becomes +1, pressing S becomes -1, and so on.
	var forward_input: float = Input.get_axis("move_back", "move_forward")
	var side_input: float = Input.get_axis("move_left", "move_right")

	# Turn the raw input into a world-space direction that is relative to the
	# camera. This makes "W" always push the player away from the camera on the
	# screen, which feels natural in third-person / top-down games.
	var camera := get_viewport().get_camera_3d()
	var move_direction := Vector3(side_input, 0.0, forward_input)
	if camera:
		# The camera is tilted down, so we project its axes onto the ground plane.
		var cam_right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z)
		var cam_forward := -Vector3(camera.global_basis.z.x, 0.0, camera.global_basis.z.z)
		if cam_forward.length_squared() > 0.001:
			cam_forward = cam_forward.normalized()
		move_direction = cam_right * side_input + cam_forward * forward_input

	# "(0,0,0)" already means "not moving", so this is safe to normalize.
	move_direction = move_direction.normalized()

	# Move. move_and_slide() also stops us at walls and crates.
	velocity = move_direction * move_speed
	move_and_slide()

	# Attack handling. The cooldown counts down every frame, so it works the
	# same regardless of frame rate; is_action_just_pressed() fires once per
	# press of the Space key.
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_perform_attack()

	# Face the direction we are moving in (a small visual touch).
	if move_direction.length_squared() > 0.001:
		var target_yaw := atan2(move_direction.x, move_direction.z)
		if turn_speed > 0.0:
			# lerp_angle rotates smoothly and takes the shortest path around.
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
		else:
			rotation.y = target_yaw

## Combat hook: any enemy (zombie, boss, etc.) calls this to hurt the player.
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		die()


## One melee swing: damages every valid target inside attack_range.
## Ranges are measured flat (no height), so the target just has to be close.
func _perform_attack() -> void:
	for node in get_tree().get_nodes_in_group(attack_target_group):
		var target := node as Node3D
		if target == null or not target.has_method("take_damage"):
			continue
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() <= attack_range:
			target.take_damage(attack_damage)

func die() -> void:
	is_dead = true
	_died_label.visible = true