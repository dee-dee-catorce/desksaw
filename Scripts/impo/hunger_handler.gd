extends Node

@onready var hungry: float = 0.0


@export var mouth: RapierArea2D
var maxhunger := 100.0
var minhunger := 0.0
#@onready var trust: float = gbData.data.save.trust
var petId: String = ""
var pet


#adding this because if they were hungry enough theyd just become a food black hole
var cd: float = 3.0
var foodDb = false
@export var dialogue: Node
func loadFromSave(id: String) -> void:
	petId = id
	pet = gbData.data["saw"][petId]
	hungry = pet.get("hunger", hungry)


func hungercheck():
		if gbData.settings.get("hungerEnabled", true):
			#await get_tree().create_timer(5).timeout
			hungry -= 0.05
			#print(str(hungry) + " hunger")
			hungry = snappedf(hungry, 0.01)
			hungry = clamp(hungry, minhunger, maxhunger)
			pet.hunger = hungry
			gbData.savetodisk("user://SAVE.json", gbData.data)
			pass
			return hungry
		else:
			return maxhunger


func _onItemEnter(body: Node2D) -> void:
	#consolidate this later
	var yapNode = get_parent().get_node_or_null("yapHandler")
	if yapNode != null and yapNode.isInteracting():
		return
	if foodDb == true:
		return
	if get_parent().isSleeping or get_parent().shocked or get_parent().ragdolled:
		return
	if not body.has_node("properties"):
		return

	var props = body.get_node("properties").propertyTable

	if not props.consumable:
		return
	foodDb = true

	if hungry >= 98.0:
		dialogue.pool = dialogue.data.Full
		dialogue.send()
		awaitDB()
		return
	if props.tasteIfConsumable == 0:
		dialogue.pool = dialogue.data.EatReject
		dialogue.send()
		awaitDB()
		return
	AudioManager.play_sfx(AudioManager.eat)
	hungry += props.replenishIfConsumable
	self.get_parent().moodSys.mood += props.moodBoostIfConsumable
	dialogue.pool = _getTasteDialogue(props.tasteIfConsumable)
	dialogue.send()

	body.queue_free()
	awaitDB()


func awaitDB() -> void:
	await get_tree().create_timer(cd).timeout
	foodDb = false
	pass
func _getTasteDialogue(taste: int) -> Array:
	if taste <= 3:
		return dialogue.data.EatBad
	elif taste <= 6:
		return dialogue.data.EatOk
	else:
		return dialogue.data.EatGood

"""
					dialogueSys.pool = dialogue.data.sleepy
					dialogueSys.send()
					ao[sdkfopasdifpas pfasip[df pasdf p[asdp[asjdfjsdpfjasoi dfjiopasdfjiopasdfjiopasfjipasdjf[ipasjfipj]]]]]
					"""
