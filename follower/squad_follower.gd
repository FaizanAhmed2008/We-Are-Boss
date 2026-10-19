class_name SquadFollower
extends Node

## Reusable behaviour for allied units: formation-following AND simple combat.
##
## Drop this node on any CharacterBody3D that should follow the player as a
## squad member. Each member's slot in the formation is derived from its
## order in the "squad" group, so there is no per-member setup and no
## formation manager.
##
## AI states:
##   FOLLOW - no alive enemies: walk to the member's anchor behind the player,
##            ease to a stop, and face the player.
##   ENGAGE - an enemy from the "enemies" group is alive: stop following,
##            chase it, spread out around it (slot index chooses the angle)
##            and melee it on a cooldown. When it dies, go back to FOLLOW.
##
## All combat goes through the target's take_damage() hook, so any future
## boss just has to join the "enemies" group. Player and squad mates are in
## different groups and are therefore never attacked.

## Group the player belongs to.
@export var target_group: StringName = &"player"
## Group members of the same squad belong to (used for spacing + slot order).
@export var squad_group: StringName = &"squad"

## Distance (in meters) the lead member keeps behind the player.
@export var follow_distance: float = 2.0
## Side/forward gap between the rows and columns of the formation.
@export var formation_spacing: float = 1.2
## Walk speed while repositioning (player runs at 8, so a bit below that feels fine).
@export var move_speed: float = 6.0
## How fast the unit turns toward where it is walking.
@export var turn_speed: float = 10.0
## If a unit is closer than this to a squad mate, the player or an enemy, it is pushed away.
## Must be a bit larger than the widest collision shape so they separate *before*
## their boxes touch and get welded together by the physics engine.
@export var separation_radius: float = 1.2
## Distance at which the unit considers itself arrived at its destination and stops.
@export var arrive_distance: float = 0.4

## Group that holds valid attack targets (enemies, and later the boss).
@export var enemy_target_group: StringName = &"enemies"
## How close (in meters) the unit must be to an enemy to strike it.
@export var attack_range: float = 1.5
## Health removed from the enemy per successful hit.
@export var attack_damage: float = 10.0
## Seconds between attacks. Smaller = attacks faster.
@export var attack_cooldown: float = 1.0
## Extra reach for landing a swing while the unit is still circling into its slot.
@export var attack_hit_margin: float = 0.35

enum AIState { FOLLOW, ENGAGE }

## The CharacterBody3D this behaviour is attached to and drives.
@onready var body := get_parent() as CharacterBody3D

## Index in the "squad" group that decides this member's slot in the formation.
var _slot_index := 0
## Current state machine state (ENGAGE = an enemy is being fought).
var _state: AIState = AIState.FOLLOW
## Time left until the unit may strike again (0 = ready).
var _attack_timer := 0.0


func _ready() -> void:
	# By the time _ready runs, the whole scene tree exists, so every other
	# squad member is already in the group. Fall back to slot 0 if missing.
	_slot_index = maxi(get_tree().get_nodes_in_group(squad_group).find(body), 0)


func _physics_process(delta: float) -> void:
	if body == null:
		return

	var player := get_tree().get_first_node_in_group(target_group) as Node3D
	var enemy := _find_enemy()

	_attack_timer = maxf(_attack_timer - delta, 0.0)

	if enemy != null and player != null:
		_state = AIState.ENGAGE
		_engage(enemy, player, delta)
	elif player != null:
		_state = AIState.FOLLOW
		_follow(player, delta)
	else:
		body.velocity = Vector3.ZERO


## Nearest alive target in the enemy group (dead/freed units are skipped).
func _find_enemy() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(enemy_target_group):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage"):
			continue
		if enemy.get("is_dead") == true:
			continue
		var hp = enemy.get("health")
		if hp != null and hp <= 0.0:
			continue
		var distance := body.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Chase the enemy, stand at a slot circling it, face it, and melee it.
func _engage(enemy: Node3D, player: Node3D, delta: float) -> void:
	var to_enemy: Vector3 = enemy.global_position - body.global_position
	to_enemy.y = 0.0
	var target_distance := maxf(to_enemy.length(), 0.001)

	# Stand point: circle the enemy at attack range, spread by slot index so
	# several squad members don't all pile into the same spot.
	var squad_count := maxi(get_tree().get_nodes_in_group(squad_group).size(), 1)
	var angle := _slot_index * TAU / float(squad_count)
	var stand := enemy.global_position + Vector3(sin(angle), 0.0, cos(angle)) * attack_range
	stand.y = 0.0

	var to_stand: Vector3 = stand - body.global_position
	to_stand.y = 0.0

	var move := Vector3.ZERO
	if to_stand.length() > arrive_distance:
		var speed_factor := clampf(to_stand.length() / (arrive_distance * 2.0), 0.2, 1.0)
		move = to_stand.normalized() + _separation(player, enemy)
		move = move.normalized() if move.length_squared() > 0.001 else Vector3.ZERO
		body.velocity = move * (move_speed * speed_factor)
	else:
		body.velocity = Vector3.ZERO

	body.move_and_slide()

	# Face the enemy while fighting.
	body.rotation.y = lerp_angle(body.rotation.y, atan2(to_enemy.x, to_enemy.z), clampf(turn_speed * delta, 0.0, 1.0))

	# Melee swing when close enough and the cooldown is done.
	if target_distance <= attack_range + attack_hit_margin and _attack_timer <= 0.0:
		if is_instance_valid(enemy):
			enemy.call("take_damage", attack_damage)
		_attack_timer = attack_cooldown


## Normal formation following (used when there is no enemy to fight).
func _follow(player: Node3D, delta: float) -> void:
	var anchor := _anchor_position(player)
	var to_anchor: Vector3 = anchor - body.global_position
	to_anchor.y = 0.0

	# Only reposition while we are not already standing in our slot. That is
	# what makes the squad stop whenever the player stops.
	var move := Vector3.ZERO
	if to_anchor.length() > arrive_distance:
		# Slow down a little as we near the slot for a smooth, non-jittery stop.
		var speed_factor := clampf(to_anchor.length() / (arrive_distance * 2.0), 0.2, 1.0)
		move = to_anchor.normalized() + _separation(player)
		move = move.normalized() if move.length_squared() > 0.001 else Vector3.ZERO
		body.velocity = move * (move_speed * speed_factor)
	else:
		body.velocity = Vector3.ZERO

	body.move_and_slide()

	if move.length_squared() > 0.001:
		var walk_yaw := atan2(move.x, move.z)
		body.rotation.y = lerp_angle(body.rotation.y, walk_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	else:
		# Standing in formation: keep facing the player for a tidy look.
		var to_player: Vector3 = player.global_position - body.global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.001:
			var face_yaw := atan2(to_player.x, to_player.z)
			body.rotation.y = lerp_angle(body.rotation.y, face_yaw, clampf(turn_speed * delta, 0.0, 1.0))


## Where this member should stand when following, relative to the player's facing.
## Slot layout (index -> position behind the player):
##   0 -> straight behind, nearest
##   1,2 -> one column to the left/right, slightly further back
##   3,4 -> next column out, and so on.
func _anchor_position(player: Node3D) -> Vector3:
	var back := Vector3(player.global_basis.z.x, 0.0, player.global_basis.z.z).normalized()
	var right := Vector3(player.global_basis.x.x, 0.0, player.global_basis.x.z).normalized()

	var column := int((_slot_index + 1) / 2)
	var side := -1.0 if _slot_index % 2 == 1 else 1.0

	var anchor := player.global_position
	anchor.y = 0.0
	anchor += back * (follow_distance + column * formation_spacing)
	if _slot_index > 0:
		anchor += right * (side * column * formation_spacing)
	return anchor


## Sum of small push-away vectors from nearby squad mates, the player and
## (while fighting) the target enemy, used to keep everyone from overlapping.
func _separation(player: Node3D, engage_enemy: Node3D = null) -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group(squad_group):
		if other != body:
			push += _push_away(other)
	push += _push_away(player)
	if engage_enemy != null and is_instance_valid(engage_enemy):
		push += _push_away(engage_enemy)
	return push


func _push_away(other: Node3D) -> Vector3:
	var to_other: Vector3 = body.global_position - other.global_position
	to_other.y = 0.0
	var distance := to_other.length()
	if distance < 0.001 or distance >= separation_radius:
		return Vector3.ZERO
	# Closer = stronger push, scaled to 1 right at the neighbour.
	var strength := 1.0 - distance / separation_radius
	return to_other / distance * strength