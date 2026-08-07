extends Node
class_name Select

# the thing that lets you drag around the objects in the scene, and also handles the outline when hovering

#i kinda just took a script from somewhere i think it was reddit and i swapped out the pinjoint witha  springjoin

#that mightve been a mistake
@export var outlineWidth: int
@export var sprite: Sprite2D

var _dect: Area2D
var _foundDect := false
var _hovering := false
var _currLine := 0.0
var _dragging := false
var _dragger: StaticBody2D
var _joint: DampedSpringJoint2D

var _use_x11_input_regions := false
var _input_region_id: int = 0
var _drag_capture_region_id: int = 0

const X11_INPUT_MARGIN := 3.0


func _ready() -> void:
	var detector := get_parent().find_child("Detector")
	if detector:
		_dect = detector
		_foundDect = true
		if gbData.devMode:
			print("found detector")

	_use_x11_input_regions = TransparentWindow.UsesInputRegions()

	if _use_x11_input_regions and _foundDect:
		_input_region_id = _dect.get_instance_id()
		_drag_capture_region_id = get_instance_id()
		_dect.input_pickable = true
		_dect.mouse_entered.connect(_onEnter)
		_dect.mouse_exited.connect(_onExit)
		_dect.input_event.connect(_on_detector_input)


func _process(_delta: float) -> void:
	if not _foundDect or not _dect:
		return

	if _use_x11_input_regions:
		_update_x11_input_regions()

		if _dragging:
			var mouse_pos := _dect.get_global_mouse_position()
			if _dragger:
				_dragger.global_position = mouse_pos

			if not Input.is_action_pressed("click"):
				_stopDrag()

		_update_outline()
		return

	var mousePos := _dect.get_global_mouse_position()

	if _dragging and not Input.is_action_pressed("click"):
		_stopDrag()

		if not _isMouseOver(mousePos):
			_setHover(false)

	if _dragging and _dragger:
		_dragger.global_position = mousePos

	if not _dragging:
		var nowHovering := _isMouseOver(mousePos)
		if nowHovering and not _hovering:
			_onEnter()
		elif not nowHovering and _hovering:
			_onExit()

	if _hovering and not _dragging and Input.is_action_just_pressed("click"):
		_startDrag(mousePos)

	_update_outline()


func _update_outline() -> void:
	var targetLine := float(outlineWidth) if (_hovering or _dragging) else 0.0
	_currLine = lerp(_currLine, targetLine, 0.5)
	#sprite.material.set_shader_parameter("thickness", _currLine)


func _update_x11_input_regions() -> void:
	TransparentWindow.SetInputRect(
		_input_region_id,
		_get_x11_input_rect(),
		get_parent().is_visible_in_tree()
	)

	TransparentWindow.SetInputRect(
		_drag_capture_region_id,
		get_viewport().get_visible_rect(),
		_dragging
	)


func _get_x11_input_rect() -> Rect2:
	var result := Rect2()
	var found_shape := false

	for child in _dect.get_children():
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

	if sprite and sprite.texture:
		return (sprite.global_transform * sprite.get_rect()).grow(X11_INPUT_MARGIN)

	return Rect2(_dect.global_position - Vector2(32, 32), Vector2(64, 64))


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


func _on_detector_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _dragging:
		_startDrag(_dect.get_global_mouse_position())


func _exit_tree() -> void:
	if _hovering:
		_setHover(false)

	if is_instance_valid(_dragger):
		_dragger.queue_free()
	_dragging = false
	_dragger = null
	_joint = null

	if _use_x11_input_regions:
		TransparentWindow.RemoveInputRect(_input_region_id)
		TransparentWindow.RemoveInputRect(_drag_capture_region_id)


func _isMouseOver(mousePos: Vector2) -> bool:
	var space := _dect.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mousePos
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results := space.intersect_point(query)
	return results.any(func(r): return r["collider"] == _dect)


func _startDrag(mousePos: Vector2) -> void:
	_dragging = true
	_dragger = StaticBody2D.new()
	_joint = DampedSpringJoint2D.new()
	_joint.node_a = ""
	_joint.node_b = ""
	_dragger.add_child(_joint)
	get_parent().owner.add_child(_dragger)


	await get_tree().process_frame

	if not _dragging:
		return

	_dragger.global_position = mousePos
	_joint.node_a = _dragger.get_path()
	_joint.node_b = get_parent().get_path()
	_joint.stiffness = 3000
	_joint.damping = 105
	_joint.length = 0

	if gbData.devMode:
		print("drag started")


func _stopDrag() -> void:
	_dragging = false

	if _use_x11_input_regions:
		TransparentWindow.RemoveInputRect(_drag_capture_region_id)

		_setHover(_isMouseOver(_dect.get_global_mouse_position()))

	if _dragger:
		_dragger.queue_free()
		_dragger = null
		_joint = null

	if gbData.devMode:
		print("drag stopped")


func _onEnter() -> void:
	print("entered")
	_setHover(true)


func _onExit() -> void:
	print("exit")
	_setHover(false)


func _setHover(value: bool) -> void:
	if value == _hovering:
		return

	_hovering = value

	if gbData.devMode:
		print("hovering", value)

	if value:
		GlobalVariable.clickZoneSum += 1
	else:
		GlobalVariable.clickZoneSum -= 1

	if gbData.devMode:
		print("clickZoneSum: ", GlobalVariable.clickZoneSum)

	TransparentWindow.SetClickThrough(GlobalVariable.clickZoneSum <= 0)
