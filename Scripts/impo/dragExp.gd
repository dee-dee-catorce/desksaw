extends Node

#basically dragEXJ but rewritten pretty heavily to handle all limbs
#instead of just using one detector area we are able to drag every
#rigidbody2d node

@onready var rigid_bodies_container: Node2D = get_parent() as Node2D
@export var outlineWidth: int = 4
@export var behaviornode: Node
@export var audio_player: AudioStreamPlayer2D

var _hovered_bodies: Array[RigidBody2D] = []

var _dragging := false
var _is_contributing := false
var _dragged_body: RigidBody2D
var _dragger: StaticBody2D
var _joint: PinJoint2D

var _use_x11_input_regions: bool = false
var _x11_region_bodies: Array[RigidBody2D] = []
var _x11_region_ids: Array[int] = []

# Small padding
const X11_INPUT_MARGIN := 3.0
const X11_INPUT_FALLBACK_HALF_SIZE := 24.0

func _ready() -> void:
	if not rigid_bodies_container:
		push_error("there is no parent rigid body")
		return

	_use_x11_input_regions = TransparentWindow.UsesInputRegions()

	#pass through every limb, then apply the signals
	for child in rigid_bodies_container.get_children():
		if child is RigidBody2D:
			if _use_x11_input_regions:
				var region_id := child.get_instance_id()
				_x11_region_bodies.append(child)
				_x11_region_ids.append(region_id)
				child.tree_exiting.connect(_on_body_part_tree_exiting.bind(child, region_id))

			child.input_pickable = true
			child.mouse_entered.connect(_on_body_part_entered.bind(child))
			child.mouse_exited.connect(_on_body_part_exited.bind(child))
			child.input_event.connect(_on_body_part_input.bind(child))

func _process(_delta: float) -> void:
	if _use_x11_input_regions:
		_update_x11_input_regions()

	#dragging active state
	if _dragging:
		var mouse_pos := rigid_bodies_container.get_global_mouse_position()
		
		if is_instance_valid(_dragger):
			_dragger.global_position = mouse_pos

		#stop dragging
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_stopDrag()
			return

	elif not _use_x11_input_regions:
		# check our cursor pos if we're hovering in transparent space
		# since we have click through we need this else the cursor
		# will never register as entering a limb
		if GlobalVariable.clickZoneSum <= 0:
			_isMouseOver()
		#if we are hovering, we have to make sure the cursor didn't slip off the expie
		else:
			_validateHoverState()

func _update_x11_input_regions() -> void:
	for body in _x11_region_bodies:
		if not is_instance_valid(body):
			continue

		TransparentWindow.SetInputRect(
			body.get_instance_id(),
			_get_body_input_rect(body),
			body.is_visible_in_tree()
		)

func _get_body_input_rect(body: RigidBody2D) -> Rect2:
	var result := Rect2()
	var found_shape := false

	for child in body.get_children():
		if not (child is CollisionShape2D):
			continue

		var collision := child as CollisionShape2D
		if collision.disabled or collision.shape == null:
			continue

		var local_rect := _shape_local_rect(collision.shape)
		if not local_rect.has_area():
			continue

		var shape_rect := collision.global_transform * local_rect
		if found_shape:
			result = result.merge(shape_rect)
		else:
			result = shape_rect
			found_shape = true

	if found_shape:
		return result.grow(X11_INPUT_MARGIN)

	var found_visible_sprite := false
	for child in body.get_children():
		if child is Sprite2D and child.is_visible_in_tree():
			var limb_sprite := child as Sprite2D
			if limb_sprite.texture == null:
				continue

			var sprite_rect := limb_sprite.global_transform * limb_sprite.get_rect()
			if found_visible_sprite:
				result = result.merge(sprite_rect)
			else:
				result = sprite_rect
				found_visible_sprite = true

	if found_visible_sprite:
		return result.grow(X11_INPUT_MARGIN)

	var half_size := Vector2(X11_INPUT_FALLBACK_HALF_SIZE, X11_INPUT_FALLBACK_HALF_SIZE)
	return Rect2(body.global_position - half_size, half_size * 2.0)

func _shape_local_rect(shape: Shape2D) -> Rect2:
	if shape is RectangleShape2D:
		var rect_shape := shape as RectangleShape2D
		return Rect2(-rect_shape.size * 0.5, rect_shape.size)

	if shape is CircleShape2D:
		var circle := shape as CircleShape2D
		var size := Vector2.ONE * circle.radius * 2.0
		return Rect2(-size * 0.5, size)

	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var size := Vector2(capsule.radius * 2.0, capsule.height)
		return Rect2(-size * 0.5, size)

	if shape is ConvexPolygonShape2D:
		var polygon := shape as ConvexPolygonShape2D
		if polygon.points.is_empty():
			return Rect2()
		var rect := Rect2(polygon.points[0], Vector2.ZERO)
		for point in polygon.points:
			rect = rect.expand(point)
		return rect

	return Rect2()

func _on_body_part_tree_exiting(body: RigidBody2D, region_id: int) -> void:
	TransparentWindow.RemoveInputRect(region_id)
	_on_body_part_exited(body)

func _exit_tree() -> void:
	for region_id in _x11_region_ids:
		TransparentWindow.RemoveInputRect(region_id)

	if _is_contributing:
		_is_contributing = false
		GlobalVariable.clickZoneSum -= 1
		TransparentWindow.SetClickThrough(GlobalVariable.clickZoneSum <= 0)

##Function that checks if the mouse is currently hovering over rigidbodies.
func _isMouseOver() -> void:
	var space_state := rigid_bodies_container.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = rigid_bodies_container.get_global_mouse_position()
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var results := space_state.intersect_point(query)
	
	#basically the same as mouseOver from the original script, but we have to loop through
	#all available limbs. BUT we only pick the first limb we find, hence the break statement
	for res in results:
		var collider: Object = res["collider"]
		if collider is RigidBody2D and collider.get_parent() == rigid_bodies_container:
			_on_body_part_entered(collider as RigidBody2D)
			break

#reused code, bleehh. it works at least
##Validates the currently hovered bodies to prevent the click-through from getting stuck.
func _validateHoverState() -> void:
	if _hovered_bodies.is_empty():
		return

	var space_state := rigid_bodies_container.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = rigid_bodies_container.get_global_mouse_position()
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results := space_state.intersect_point(query)

	#store every detected collider in an array
	var current_colliders: Array = []
	for res in results:
		current_colliders.append(res["collider"])

	#loop backwards through the array and delete delements if need be
	for i in range(_hovered_bodies.size() - 1, -1, -1):
		var body: RigidBody2D = _hovered_bodies[i]
			
		#if the expie somehow disappeared, or we are actually not hovering
		#over a limb anymore, forcefully exit
		if not is_instance_valid(body) or not current_colliders.has(body):
			_on_body_part_exited(body)

func _on_body_part_entered(body: RigidBody2D) -> void:
	if _hovered_bodies.has(body):
		return
		
	_hovered_bodies.append(body)
	_updateHoverState()


func _on_body_part_exited(body: RigidBody2D) -> void:
	if not _hovered_bodies.has(body):
		return
	
	_hovered_bodies.erase(body)
	_updateHoverState()


##Func for handling clicking on rigidbodies.
func _on_body_part_input(_viewport: Node, event: InputEvent, _shape_idx: int, body: RigidBody2D) -> void:
	if event is not InputEventMouseButton:
		return
		
	if event.pressed and not _hovered_bodies.is_empty() and _hovered_bodies.back() == body and not _dragging:
		#dragging
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if Input.is_action_pressed("ctrl"):
				GlobalVariable.consoleF(true)
				return
			var mouse_pos := rigid_bodies_container.get_global_mouse_position()
			_startDrag(body, mouse_pos)
		#pet limb
		if event.button_index == MOUSE_BUTTON_LEFT:
			behaviornode.petLimb(body)


func _updateHoverState() -> void:
	var is_hovering := not _hovered_bodies.is_empty()
	
	var should_contribute := is_hovering or _dragging
	if should_contribute == _is_contributing:
		return
	_is_contributing = should_contribute

	if should_contribute:
		GlobalVariable.clickZoneSum += 1
	else:
		GlobalVariable.clickZoneSum -= 1

	#change cursor icon
	#due to GODOT forcefully changing cursor icons when you stop hovering
	#over rigidbodies, the cursor will flicker if you drag and have your
	#cursor outside of the expie collision areas. dunno how to fix it
	if _dragging:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	elif is_hovering:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	TransparentWindow.SetClickThrough(GlobalVariable.clickZoneSum <= 0)

func _startDrag(body: RigidBody2D, mouse_pos: Vector2) -> void:
	_dragging = true
	_dragged_body = body

	_dragger = StaticBody2D.new()
	_dragger.global_position = mouse_pos

	_joint = PinJoint2D.new()
	_dragger.add_child(_joint)

	get_tree().current_scene.add_child(_dragger)

	if behaviornode:
		behaviornode.beingDragged = true

	await get_tree().process_frame

	if not _dragging or not is_instance_valid(_dragger) or not is_instance_valid(_dragged_body):
		return
	
	_dragger.global_position = mouse_pos
	_joint.node_a = _joint.get_path_to(_dragger)
	_joint.node_b = _joint.get_path_to(_dragged_body)
	_joint.softness = 7.0

	_updateHoverState()
	print("we dragging: ", body.name)


func _stopDrag() -> void:
	_dragging = false
	_dragged_body = null

	if behaviornode:
		behaviornode.beingDragged = false

	if is_instance_valid(_dragger):
		_dragger.queue_free()
		_dragger = null
		_joint = null

	_updateHoverState()
	print("DRAG STOPPED")
