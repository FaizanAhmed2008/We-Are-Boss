class_name AlliedZombie
extends CharacterBody3D

## An allied zombie that follows the player around the arena.
## Movement is entirely driven by its SquadFollower child node; this script
## only owns the unit's own health so it can be damaged / die later, just
## like the enemy zombie.

## Maximum health for this unit.
@export var max_health: float = 100.0
## Current health (starts at max). Reduced via take_damage().
var health: float

var is_dead: bool = false


func _ready() -> void:
	# Current health always starts at the maximum.
	health = max_health


## Generic combat hook, matching the enemy zombie's take_damage() signature,
## so weapons/effects can later treat hostile and allied units the same way.
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		die()


func die() -> void:
	is_dead = true
	queue_free()