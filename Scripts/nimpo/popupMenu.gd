extends Control

var offset = Vector2.ZERO
var dragging = false
var first = true
signal choice_made(result: bool)
func _ready():
	self.visible = true
	$ClickArea.enabled = self.visible
	
	position = Vector2i(GlobalVariable.screenWidth / 4, GlobalVariable.screenHeight / 4)

func _process(_delta: float):
	if dragging:
		global_position = get_global_mouse_position() - offset

func _downDrag():
	if gbData.devMode:
		print("dragging")
	offset = get_global_mouse_position() - global_position
	dragging = true
	move_to_front()

func _upDrag():
	dragging = false


func setup(text: String = "text") -> bool:
	var yes: Button = $Main/YES
	var no: Button = $Main/NO
	$Main/RichTextLabel.text = text

	yes.pressed.connect(func(): choice_made.emit(true))
	no.pressed.connect(func(): choice_made.emit(false))

	var result: bool = await choice_made
	return result
