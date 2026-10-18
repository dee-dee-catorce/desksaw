@tool
extends PanelContainer

@export_category("Settings")
@export_multiline var itemName: String:
	set(v):
		itemName = v
		_refresh()
@export var itemIcon: Texture:
	set(v):
		itemIcon = v
		_refresh()
@export var sceneToInstance: PackedScene

@export_category("Nodes - DONT CHANGE")
@export var texRect: TextureRect
@export var label: RichTextLabel
@export var btn: Button

func _refresh() -> void:
	texRect.texture = itemIcon
	# Item names come from scene file names, so route them through the
	# translation table as ITEM_<NAME>_TEXT. If a locale has no entry the raw
	# file name is shown, which keeps the list usable everywhere.
	var key := "ITEM_%s_TEXT" % itemName.to_upper()
	var translated := tr(key)
	label.text = itemName if translated == key else translated

func _ready() -> void:
	if not Engine.is_editor_hint():
		_refresh()
		btn.pressed.connect(_on_button_press)

func _on_button_press() -> void:
	print("pressed %s!" % [itemName])
