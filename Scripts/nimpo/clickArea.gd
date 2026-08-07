extends Control
class_name ClickAreaControl
"""
	theres a fun line of text you will see if you go back to a really old commit and go to this file

	handles clickthrough toggling (not the actual thing itself)

	go to the singular .CS file for that, ask ZeadenTheBirb about it i dont know anything about c#
"""


@export var enabled: bool = true:
	set(value):
		enabled = value
		_sync_contribution()

var cur: bool = false
var contributing: bool = false

var _use_x11_input_regions: bool = false
var _input_region_id: int = 0

func _ready() -> void:
	_use_x11_input_regions = TransparentWindow.UsesInputRegions()
	_input_region_id = get_instance_id()

func _process(_delta: float) -> void:
	if _use_x11_input_regions:
		TransparentWindow.SetInputRect(
			_input_region_id,
			get_global_rect().grow(2.0),
			enabled and is_visible_in_tree()
		)
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var inside: bool = (
		mouse_pos.x >= global_position.x and
		mouse_pos.x <= global_position.x + size.x and
		mouse_pos.y >= global_position.y and
		mouse_pos.y <= global_position.y + size.y
	)
	change(inside)

func _exit_tree() -> void:
	if _use_x11_input_regions:
		TransparentWindow.RemoveInputRect(_input_region_id)

	if contributing:
		contributing = false
		GlobalVariable.clickZoneSum -= 1
		TransparentWindow.SetClickThrough(GlobalVariable.clickZoneSum <= 0)

func change(t: bool) -> void:
	if t == cur:
		return
	cur = t
	if gbData.devMode:
		print(t)
	_sync_contribution()

func _sync_contribution() -> void:
	var should_contribute: bool = cur and enabled
	if should_contribute == contributing:
		return
	contributing = should_contribute
	GlobalVariable.clickZoneSum += 1 if contributing else -1
	if gbData.devMode:
		print(GlobalVariable.clickZoneSum)
	TransparentWindow.SetClickThrough(GlobalVariable.clickZoneSum <= 0)
