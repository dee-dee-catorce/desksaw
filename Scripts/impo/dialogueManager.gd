extends Node
class_name Dialogue

var data
@onready var dialogueTimer = $dialogueTimer
@export var richtextlabel: RichTextLabel
@export var textspeed: float = 0.04
var pause: Array = [",", ".", "!"]

var bb: Array = ["[shake]", "[wave]"]
var isTyping: bool = false
var pool: Array = []
var speedMod: float = 1.0

signal starttalking()
signal stoptalking()

var tre: int = 0

@export var fasdfasdfasddfas: Node
var passive_timer: SceneTreeTimer = null

## Text Sound Variables:
var base_db: float = -10 # Set base audio level of text
var variance_db: float = 3.0

func _ready() -> void:
	data = gbData.getDialogueForSkin(GlobalVariable.userSkinPath)
	richtextlabel.add_theme_font_size_override("normal_font_size", gbData.settings.expieDialogueSize)
	print("LOADED DIALOGUE KEYS: ", data.keys())

	
func typeOut(string: String, speed_multiplier: float = 1.0):
	if gbData.settings.get("mute", false): return

	tre += 1
	var h = tre

	richtextlabel.add_theme_font_size_override("normal_font_size", gbData.settings.expieDialogueSize)
	isTyping = true
	richtextlabel.text = string
	richtextlabel.visible_characters = 0

	starttalking.emit()

	AudioServer.set_bus_mute(AudioServer.get_bus_index("Text"), not gbData.settings.dialogueSoundEnabled) # Update bus if sound is muted or not

	var i = 0
	while i < string.length():
		if tre != h: return

		if string[i] == "[":
			while i < string.length() and string[i] != "]":
				i += 1
			i += 1
			continue

		richtextlabel.visible_characters += 1
		var current_char = string[i]

		var wait = textspeed * speed_multiplier
		if current_char in pause:
			wait *= 8

		AudioManager.play_sfx(AudioManager.speech, 1, base_db + randf_range(-variance_db, variance_db), 1 + randf_range(-.2, .2), false, 0.5, "", "Text")
		await get_tree().create_timer(wait).timeout
		i += 1

	if tre != h: return

	isTyping = false
	stoptalking.emit()
	await get_tree().create_timer(string.length() * 0.2).timeout

	if tre == h:
		richtextlabel.visible_characters = 0


func send(cooldown: float = 0.0, ignoreCooldown: bool = true) -> void:
	if (not dialogueTimer.is_stopped() or isTyping) and not ignoreCooldown:
		#print("THE EXPIE IS OVERSTIMULATED HE WON'T TALK")
		return
	if self.get_parent().isSleeping:
		print("sleeping")
		return
	if pool.size() > 0:
		var text: String = pool.pick_random()
		var effectiveSpeed = speedMod


		var res = TextWarper.checkTag(text, effectiveSpeed)

		text = res[0]
		effectiveSpeed= res[1]

		typeOut(text, effectiveSpeed)

		await stoptalking

		if cooldown > 0.0:
			dialogueTimer.start(cooldown)


func setDia(stra: String, speed: float, cooldown: float = 0.0, ignoreCooldown: bool = true) -> void:
	if (not dialogueTimer.is_stopped() or isTyping) and not ignoreCooldown:
		#print("THE EXPIE IS OVERSTIMULATED HE WON'T TALK")
		return

	typeOut(stra, speed)
	await stoptalking

	if cooldown > 0.0:
		dialogueTimer.start(cooldown)

func is_dialogue_playing() -> bool:
	return isTyping

func is_dialogue_visible() -> bool:
	return isTyping or richtextlabel.visible_characters > 0

