
extends StaticBody2D


#reskinned drag script essentially iirc idk im adding this comment a few days afrter this was implemented

var dragging := false
var offset := Vector2.ZERO
var _hovering := false

var _use_x11_input_regions := false
var _input_region_id: int = 0
var _drag_capture_region_id: int = 0

const X11_INPUT_MARGIN := 3.0

var area2d: Area2D
var _foundDect := false


func _ready() -> void:
	var detector := find_child("Detector")

	if detector is Area2D:
		area2d = detector
		_foundDect = true

	_use_x11_input_regions = TransparentWindow.UsesInputRegions()

	if _foundDect:
		area2d.input_pickable = true
		area2d.mouse_entered.connect(_on_area_entered)
		area2d.mouse_exited.connect(_on_area_exited)
		area2d.input_event.connect(_on_detector_input)

		if _use_x11_input_regions:
			_input_region_id = area2d.get_instance_id()
			_drag_capture_region_id = get_instance_id()


func _process(_delta: float) -> void:
	if not _foundDect or not is_instance_valid(area2d):
		return

	if _use_x11_input_regions:
		_update_x11_input_regions()

	var mouse_pos := area2d.get_global_mouse_position()

	if dragging:
		global_position = mouse_pos + offset

		if not Input.is_action_pressed("click"):
			_stop_drag()

		return

	if not _use_x11_input_regions:
		var now_hovering := _is_mouse_over(mouse_pos)

		if now_hovering and not _hovering:
			_set_hover(true)
		elif not now_hovering and _hovering:
			_set_hover(false)

		if _hovering and Input.is_action_just_pressed("click"):
			_start_drag(mouse_pos)


func _input(event: InputEvent) -> void:
	if _use_x11_input_regions:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed and dragging:
				_stop_drag()


func _on_detector_input(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not dragging:
				_start_drag(area2d.get_global_mouse_position())


func _is_mouse_over(mouse_pos: Vector2) -> bool:
	var space := area2d.get_world_2d().direct_space_state

	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := space.intersect_point(query)

	return results.any(
		func(result):
			return result["collider"] == area2d
	)


func _start_drag(mouse_pos: Vector2) -> void:
	if dragging:
		return

	dragging = true
	offset = global_position - mouse_pos

	if _use_x11_input_regions:
		TransparentWindow.SetInputRect(
			_drag_capture_region_id,
			get_viewport().get_visible_rect(),
			true
		)


func _stop_drag() -> void:
	dragging = false

	if _use_x11_input_regions:
		TransparentWindow.RemoveInputRect(_drag_capture_region_id)

		_set_hover(
			_is_mouse_over(area2d.get_global_mouse_position())
		)


func _set_hover(value: bool) -> void:
	if value == _hovering:
		return

	_hovering = value

	if value:
		GlobalVariable.clickZoneSum += 1
	else:
		GlobalVariable.clickZoneSum -= 1

	TransparentWindow.SetClickThrough(
		GlobalVariable.clickZoneSum <= 0
	)


func _on_area_entered() -> void:
	_set_hover(true)


func _on_area_exited() -> void:
	if dragging:
		return

	_set_hover(false)


func _update_x11_input_regions() -> void:
	TransparentWindow.SetInputRect(
		_input_region_id,
		_get_input_rect(),
		is_visible_in_tree()
	)

	TransparentWindow.SetInputRect(
		_drag_capture_region_id,
		get_viewport().get_visible_rect(),
		dragging
	)


func _get_input_rect() -> Rect2:
	var result := Rect2()
	var found_shape := false

	for child in area2d.get_children():
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

	return Rect2(
		global_position - Vector2(32, 32),
		Vector2(64, 64)
	)


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


func _exit_tree() -> void:
	if _hovering:
		_set_hover(false)

	if _use_x11_input_regions:
		TransparentWindow.RemoveInputRect(_input_region_id)
		TransparentWindow.RemoveInputRect(_drag_capture_region_id)
