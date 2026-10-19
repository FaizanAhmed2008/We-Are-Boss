class_name Zombie
extends CharacterBody3D

## A placeholder melee enemy: it notices the player when close enough,
## walks straight toward them, and attacks when within arm's reach.

## Walking speed while chasing (player runs at 8, so you can always escape).
@export var move_speed: float = 2.5
## Distance (in meters) at which the zombie "sees" the player and starts chasing.
@export var detection_range: float = 12.0
## How close the zombie gets before it stops walking. Keep this below attack_range.
@export var stop_distance: float = 1.2
## How fast the zombie turns to face the player.
@export var turn_speed: float = 8.0

## Combat stats, kept as plain exports so future enemies and the boss can
## reuse the same pattern (and can all be tweaked in the inspector).

## How close the player must be (in meters) for an attack to land.
@export var attack_range: float = 1.8
## Seconds between attacks. Smaller = attacks faster.
@export var attack_cooldown: float = 1.0
## Health removed from the player per successful hit.
@export var attack_damage: float = 10.0

## Maximum health for this zombie.
@export var max_health: float = 100.0
## Current health, stored here on the zombie (starts at max_health).
var health: float

## Time left until the zombie can attack again (0 = ready to attack).
var _attack_timer: float = 0.0

func _ready() -> void:
	# Current health always starts at the maximum.
	health = max_health

func _physics_process(delta: float) -> void:
	# Find the player through the "player" group (added in player.tscn).
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	# Vector from us to the player, flattened so we ignore height differences.
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var distance_to_player: float = to_player.length()

	# Detection is just a distance check, re-evaluated every frame:
	# inside detection_range = chasing, outside = standing still.
	var is_detected: bool = distance_to_player <= detection_range

	# Chase straight at the player, but stop once close enough to not shove them.
	var move_direction := Vector3.ZERO
	if is_detected and distance_to_player > stop_distance:
		move_direction = to_player.normalized()

	velocity = move_direction * move_speed
	move_and_slide()

	# Face the player while walking (and while attacking, even when standing still).
	if move_direction.length_squared() > 0.001 or distance_to_player <= attack_range:
		var target_yaw := atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

	# Attack: only when the player is close enough AND enough time has passed
	# since the last hit. The cooldown counts down every frame, so it works the
	# same regardless of frame rate.
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if is_detected and distance_to_player <= attack_range and _attack_timer <= 0.0:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)
		_attack_timer = attack_cooldown

## Call this when the zombie gets hit (attacks come in a later step).
func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		die()

func die() -> void:
	queue_free()