extends Node

@export var window: Control
@export var stat = {
	"mood": 0.0,
	"hunger": 0.0,
	"sleep": 0.0,
}

func _ready() -> void:
	upd(stat)

func upd(stats: Dictionary) -> void:
	var ilist = window.get_node("ItemList")
	var textTemplate = window.get_node("ItemList/stat")

	for child in ilist.get_children():
		if child != textTemplate:
			child.queue_free()
	

	for key in stats.keys():
		#update asdfhsdfuioghj
		var val = stats[key]
		var new_stat = textTemplate.duplicate()
		

		new_stat.show()
		new_stat.text = _get_translation(str(key)) + ": " + str(val)
		ilist.add_child(new_stat)
		


func _get_translation(key : String) -> String:
	match key:
		"mood": 
			return tr("STATS_MOOD_TEXT")
		"hunger":
			return tr("STATS_HUNGER_TEXT")
		"sleep":
			return tr("STATS_SLEEP_TEXT")
		"friendliness":
			return tr("STATS_FRIENDLINESS_TEXT")
		_ : 
			return key


func _process(_delta: float) -> void:
	pass
