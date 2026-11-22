extends PanelContainer
var input: String
var mod: String
var chance: float = 0
@export_category("Window")


@export_category("no touchy")
@export_category("no touchy!!")
@export_category("no touchy!!!")
@export_category("no touchy!")


@export var inputText:Control
@export var modText:Control
@export var output:Control
# Called when the node enters the scene tree for the first time.


func modChange() -> void:

	mod = modText.text

	input = inputText.text
	output.text =  TextWarper.manualTransform(input,mod,chance)


	
	pass # Replace with function body.


func _on_h_slider_value_changed(value: float) -> void:
	chance = value
	modChange()
	pass # Replace with function body.
