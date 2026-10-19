class_name Boss
extends CharacterBody3D

## Large melee boss prototype. It watches the player and the allied squad,
## picks the nearest living threat, chases it down and lands heavy melee hits
## on a cooldown.
##
## Behaviour is kept in clearly separated functions so later tasks can add
## extra attack types and fight phases without rewriting the core loop:
##   _find_nearest_target() -> choose the closest living threat
##   _chase_target()        -> walk after it until in melee range
##   _face_target()         -> turn to look at the current threat
##   _try_attack()          -> melee swing when in range and cooldown ready
##
## Health/combat follows the project convention (take_damage(), health,
## max_health, is_dead). Being part of the "enemies" group (set in boss.tscn)
## makes the player melee and every allied zombie target the boss automatically.

## Groups the boss scans for targets (player + allied squad).
@export var target_groups: Array[StringName] = [&"player", &"squad"]

## Walking speed while chasing its target (slow, but heavy).
@export var move_speed: float = 2.0
## Distance (in metres) at which the boss wakes up and starts chasing.
@export var detection_range: float = 20.0
## How fast the boss turns to face its target.
@export var turn_speed: float = 2.5

## How close (in metres) the target must be for a melee hit to land.
@export var attack_range: float = 3.5
## Extra reach so a swing can land while the boss is still closing in.
@export var attack_hit_margin: float = 0.5
## Seconds between attacks. Smaller = attacks faster.
@export var attack_cooldown: float = 1.6
## Health removed from the target per successful hit.
@export var attack_damage: float = 40.0

## Maximum health for the boss.
@export var max_health: float = 1000.0
## Current health, stored here on the boss (starts at max_health).
var health: float

## True once health reaches 0: stops all behaviour and ends the fight.
var is_dead: bool = false

## The unit the boss is currently chasing (player or allied zombie).
var current_target: Node3D

## Time left until the boss can attack again (0 = ready to attack).
var _attack_timer: float = 0.0


func _ready() -> void:
	# Current health always starts at the maximum.
	health = max_health


func _physics_process(delta: float) -> void:
	# Once dead the boss neither moves, turns nor attacks anymore.
	if is_dead:
		velocity = Vector3.ZERO
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)

	# Re-evaluate the nearest living threat every frame, so the boss switches
	# to whoever is closest and drops targets that have just died.
	current_target = _find_nearest_target()

	if current_target == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_chase_target(delta)
	move_and_slide()
	_face_target(delta)
	_try_attack(current_target)


## Returns the closest living unit in the player/squad groups that is inside
## detection_range, or null when there is nothing left to fight.
func _find_nearest_target() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			var candidate := node as Node3D
			if candidate == null or candidate == self:
				continue
			if not _is_living(candidate):
				continue
			var distance := global_position.distance_to(candidate.global_position)
			if distance <= detection_range and distance < best_distance:
				best_distance = distance
				best = candidate
	return best


## A target counts as living when it still exists, is not flagged dead, and
## still has health above zero.
func _is_living(unit: Node3D) -> bool:
	if not is_instance_valid(unit):
		return false
	if unit.get("is_dead") == true:
		return false
	var hp = unit.get("health")
	if hp != null and hp <= 0.0:
		return false
	return true


## Walk straight at the current target, stopping once inside melee reach.
func _chase_target(_delta: float) -> void:
	var to_target: Vector3 = current_target.global_position - global_position
	to_target.y = 0.0

	var move_direction := Vector3.ZERO
	if to_target.length() > attack_range:
		move_direction = to_target.normalized()

	velocity = move_direction * move_speed


## Smoothly turn to face the current target.
func _face_target(delta: float) -> void:
	var to_target: Vector3 = current_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.001:
		return
	var target_yaw := atan2(to_target.x, to_target.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


## Melee swing: deals attack_damage when the target is close enough and the
## cooldown has expired. New attack types can be added later alongside this
## function without touching the core loop.
func _try_attack(target: Node3D) -> void:
	if _attack_timer > 0.0:
		return
	if not is_instance_valid(target) or not _is_living(target):
		return
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() > attack_range + attack_hit_margin:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	_attack_timer = attack_cooldown


## Call this when the boss gets hit. Matches the damage convention shared by
## the player, allied zombies and enemy zombies.
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		die()


## Mark the boss dead and end its behaviour. The health bar hides itself the
## moment is_dead becomes true.
func die() -> void:
	is_dead = true
	current_target = null
	velocity = Vector3.ZERO
	queue_free()