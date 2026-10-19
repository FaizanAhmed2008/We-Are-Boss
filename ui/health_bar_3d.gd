class_name HealthBar3D
extends Node3D

## Reusable 3D health bar for any unit (player, enemies, allies, boss, ...).
##
## Attach this node as a child of a unit that owns the properties
## `max_health`, `health` and (optionally) `is_dead`. Every frame it simply
## reads those properties, so any change -- take_damage(), healing, death --
## shows up immediately with no wiring. On death it hides itself (number
## included). The bar is always billboarded toward the camera.
##
## Everything is built at runtime (two quads + a label), so no art assets,
## fonts or UI scenes are needed.

## Bar size in world metres.
@export var bar_size := Vector2(1.2, 0.12)
## Where the HP-number label sits relative to the bar.
@export var label_offset := Vector3(0.0, 0.26, 0.0)
## Fill colour of the remaining-health part.
@export var fill_color := Color(0.45, 0.85, 0.4, 1.0)
## Background (empty) colour behind the fill.
@export var background_color := Color(0.08, 0.08, 0.08, 0.85)
## Show a "current / max" number above the bar.
@export var show_numbers := true

var _fill: MeshInstance3D
var _label: Label3D
var _half_width: float


func _ready() -> void:
	_half_width = bar_size.x * 0.5

	var background := _make_bar_mesh(background_color)
	background.position = Vector3(0.0, 0.0, -0.005)
	add_child(background)

	_fill = _make_bar_mesh(fill_color)
	# Anchored to the left edge so the bar drains left -> right as health drops.
	_fill.position = Vector3(-_half_width, 0.0, 0.0)
	_fill.scale.x = 1.0
	add_child(_fill)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.pixel_size = 0.0022
	_label.outline_size = 10
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = label_offset
	add_child(_label)

	_refresh()

	if show_numbers:
		_label.text = "%d / %d" % [owner_health(), owner_max_health()]


func _process(_delta: float) -> void:
	_refresh()
	if show_numbers:
		_label.text = "%d / %d" % [owner_health(), owner_max_health()]


## The unit this bar belongs to: whatever node this component is a child of.
func _owner() -> Node:
	return get_parent()


func owner_health() -> int:
	var owner := _owner()
	return ceili(owner.health) if is_instance_valid(owner) and owner.get("health") != null else 0


func owner_max_health() -> int:
	var owner := _owner()
	return ceili(owner.max_health) if is_instance_valid(owner) and owner.get("max_health") != null else 1


func _refresh() -> void:
	var owner := _owner()
	# Hide when the owner is gone, has no health, or has died.
	var owned_health_ok := is_instance_valid(owner) and owner.get("max_health") != null
	if not owned_health_ok or owner.health <= 0.0 or (owner.get("is_dead") == true):
		visible = false
		return
	visible = true

	var ratio := clampf(owner.health / float(owner.max_health), 0.0, 1.0)
	# Keep the left edge glued to the background's left edge while the right
	# edge moves in as health drops.
	_fill.position.x = -_half_width * (1.0 - ratio)
	_fill.scale.x = maxf(ratio, 0.001)


func _make_bar_mesh(color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = color

	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = bar_size
	mesh_instance.mesh = quad
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance