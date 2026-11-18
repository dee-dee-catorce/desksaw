extends Node2D

@export var text: RichTextLabel
@onready var parent: Node2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if parent:
		global_position = lerp(global_position, parent.global_position, .1)

	print(position)
	pass


func changeFont(path) -> void:
	#if the passed path is a font, change it tothat
	#text.add_theme_font_override()
	pass
