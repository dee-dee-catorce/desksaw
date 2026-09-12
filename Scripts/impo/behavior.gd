extends Node
class_name expieBehaviour

"""
hey this is like 2 days before 0.2 releases

most of this script is 2014 toby fox level bullshit

and i need to recode it asap


im putting this here as a reminder

"""


#referebces for systems to be used by this script
@onready var faceSys = $faceHandler
@onready var moodSys = $moodHandler
@onready var moveSys :expieMoveSys= $movementHandler
@onready var sleepHandler = $sleepManager
@onready var hungerHandler = $hungerHandler
@onready var dialogueSys = $dialogue
@onready var detectRange = $detRadius
@onready var statUpd = $statWatcher

@onready var settings = gbData.settings
#settings for dialoguetimer

##Timer used for keeping time since the last recent pet.
@onready var pet_timer: Timer = $petTimer

@export var sleepParticle: CPUParticles2D
##How much does the pet timer last. Keep it higher getUpTimer so the wrong dialogue
##doesn't get sent.
var pet_timer_inc := 10.0
##How many times has the node been pet recently.
var pet_count := 0


var beingDragged := false

var ragdolled := false

var launchflag := false


var wander := true


# every spawned sawian will be assigned an id regardless of if they exist for like a few seconds or days on end.
# this is how they are stored in SAVE.json
var petId := ""


#status, stuff
# used for emotions and others related
var isTired := false
var isSleeping := false
var isHungry := false
var isSad := false
var shocked := false
##When set, the expie looks toward and walks toward this node instead of the mouse.
var attention: Node2D = null


#unused atm
var isDead := false


#might be worth it change most of the timers in this script with variables
#so we can avoid magic numbers
##How long does it take the sawian to get up after being ragdolled.
var getUpTimer := 5.0
##How long does it take for the sawian to send dialogue after getting up.
var getUpTimerMsg := 1.5

#you get the idea
var hungryRemind := 90.0


#ricktate in seconds for updating status
var tick: float = 5.0

# table for every emotion avaibalekl to them
enum emotionz {
	normal, sad, sleep, tired, scared, panic, happy
}
var currentEmotion = emotionz.normal:
	set(value):
		currentEmotion=value
		moveSys.currentEmotion=value

func _ready() -> void:
	if petId == "":
		var skinName = GlobalVariable.userSkinPath.substr(0, len(GlobalVariable.userSkinPath) - 1)
		skinName = skinName.substr(skinName.rfind("/") + 1)
		petId = gbData.addPet(skinName)

	get_parent().get_parent().set_meta("itemName", petId)
	

	#im very sorry that i had to comment this out i have no idea what its supposed to do and it was throwing an error
	"""
	# Set debug text to Node's ID:
	$"../textParent/DebugText".text = "Test"
	print(get_parent().get_parent().get_children().find(self))
	connect("toggleDebugText", _on_debugToggle_signal)
	"""

	#setup For spawn
	_initalSpawn()
	

func _initalSpawn() -> void:
	#teag you can like guess what this does
	faceSys.setEmotion("default")
	#this specific line  is the reason why there was a bug in v0.1 and below where the face was permanantly in a shocked state
	#not the entire reason but its why it was locked into this emotion
	moveSys.sigragdoll.connect(shock)


	#this dont even work properly it always puts it somewhere else.
	moveSys.rigid.global_position.x = float(GlobalVariable.screenWidth) / 2
	moveSys.rigid.global_position.y = float(GlobalVariable.screenHeight) * 2

	#load the stats from the id (for presistance)
	moodSys.loadFromSave(petId)
	hungerHandler.loadFromSave(petId)
	sleepHandler.loadFromSave(petId)


	tempRagdoll()
	
	#initialized stuff

	wandering()
	passivetalk()
	checker()
	pass

func sleep():
	#handle sleeep loop this is probably one of the worst ways i couldve handled this ill fix it later
	while get_tree():
			#print("2")
			if sleepHandler.sleepCheck() < 5.0:
				#break if its below 10 (aka good enough to get up)
				sleepParticle.emitting = false
				moveSys.rigid.global_position = moveSys.rigidtorso.global_position
				moveSys.rigid.linear_velocity = Vector2.ZERO
				moveSys.rigid.freeze = false
				isSleeping = false
				moveSys.ragdoll(true)
				ragdolled = false
				break

				
			moveSys.rigid.freeze = true
			sleepParticle.emitting = true
			faceSys.setEmotion("sleep")
			moveSys.ragdoll(false)
			ragdolled = true
			sleepHandler.tiredness -= randf_range(0.05, 0.15)
			moodSys.mood += 0.025


			await get_tree().create_timer(tick / 7).timeout
	pass

func checker():
	while get_tree():
		#this was calling each function like 90 times per check which is why everyting was very extreme!
		#DONT DO THAT MISTAKE AGAIN!
		hungerHandler.hungercheck()
		var sleepN = sleepHandler.sleepCheck()
		var moodN = moodSys.moodCheck(.5)
		if not shocked and not isSleeping:
			#sleep stuff
			currentEmotion = emotionz.normal
			if sleepN > 80.0 and not $yapHandler.isInteracting():
				var sleepflag1 = false

				if !isTired:
					sleepflag1 = false
					if randi() % 4 == 0:
						dialogueSys.pool = dialogueSys.data.sleepy
						dialogueSys.send()
				isTired = true
				currentEmotion = emotionz.tired
				print("tired")
				

				if sleepN > 94.5:
					if !sleepflag1:
						sleepflag1 = true
						moveSys.initswithc(moveSys.states.resting)
						if randi() % 2 == 0:
							dialogueSys.pool = dialogueSys.data.reallySleepy
							dialogueSys.send()


				if sleepN > 95.0:
					isSleeping = true

					moveSys.rigidtorso.linear_velocity = Vector2(0, 0)
					print("sleeping")
					sleep()
			else:
				isTired = false

			#isSad s	
			if moodN < -10.0:
				isSad = true
				if moodN < -30.0:
					currentEmotion = emotionz.sad
			else:
				isSad = false

			if moodN > 50.0:
				currentEmotion = emotionz.happy

				#ungry
			if hungerHandler.hungry < 30.0 and not $yapHandler.isInteracting():
				if !isHungry:
					dialogueSys.pool = dialogueSys.data.hungry
					dialogueSys.send()
					isHungry = true
				var r = randf_range(30.0 - hungerHandler.hungry, 40.0)
				#print("hunger notif chance ", r)
				if r > 38.0:
						dialogueSys.pool = dialogueSys.data.hungry
						dialogueSys.send()

			#update
			faceSys.setEmotion(emotionz.keys()[currentEmotion])
		statUpd.stat.friendliness = $yapHandler.friendliness
		statUpd.stat.id = ("#" + GlobalVariable.getNumFromString(petId))
		statUpd.stat.mood = moodN
		statUpd.stat.hunger = hungerHandler.hungry
		statUpd.stat.sleep = snapped(sleepN, 0.1) # ???? why was it like that before?
		statUpd.upd(statUpd.stat)

		await get_tree().create_timer(tick).timeout

func _physics_process(_delta: float) -> void:
	#detect speed and aiosdhfopjkasfguopjasfgsdfhcvio[]
	#and ragdoll based on taht
	if not ragdolled and (abs(moveSys.rigid.linear_velocity.x) > moveSys.ragdollspeed or beingDragged):
		tempRagdoll()

	if ragdolled:
		moveSys.dir = 0


"""

green because it needs to catch my attention 
PLEASE FUCKING RECODE BOTH OF THESE

"""
func shock() -> void:
	shocked = true
	moodSys._tempVal(-5.0, 15)
	moodSys.mood -= 2.5
	faceSys.setEmotion("panic")

	dialogueSys.pool = dialogueSys.data.screamBIG
	dialogueSys.speedMod = 1.3
	dialogueSys.send()
	AudioManager.play_random(AudioManager.expie_whine)
	await get_tree().create_timer(2).timeout
	faceSys.setEmotion("scared")
	await get_tree().create_timer(5).timeout
	faceSys.setEmotion("sad")
	await get_tree().create_timer(13).timeout


	shocked = false

func tempRagdoll() -> void:
	moveSys.ragdoll(false)
	ragdolled = true
	moveSys.rigid.collision_layer = 0
	moveSys.rigid.collision_mask = 0
	moveSys.rigid.freeze = true
	while true:
		await get_tree().create_timer(getUpTimer + randf_range(0, 5)).timeout
		if beingDragged:
			AudioManager.play_random(AudioManager.expie_whine)
			dialogueSys.pool = dialogueSys.data.beingDragged
			dialogueSys.send(10, false)
			#fix the weird ghost collision during ragdoll
			continue
		if moveSys.rigidtorso.linear_velocity.length() > 10.0:
			continue
		break
	moveSys.rigid.collision_layer = 2
	moveSys.rigid.collision_mask = 1
	moveSys.rigid.freeze = false
	moveSys.rigid.linear_velocity.x = 0.0
	moveSys.rigid.linear_velocity.y = 0.0
	moveSys.rigid.global_position.x = moveSys.rigidtorso.global_position.x
	moveSys.rigid.global_position.y = moveSys.rigidtorso.global_position.y
	moveSys.ragdoll(true)

	ragdolled = false
	await get_tree().create_timer(getUpTimerMsg).timeout
	moveSys.initswithc(moveSys.states.idle)
	if launchflag:
		if not pet_timer.is_stopped() and pet_count >= 5:
			dialogueSys.pool = dialogueSys.data.getUpPet
		else:
			dialogueSys.pool = dialogueSys.data.getUp

	else:
		dialogueSys.pool = dialogueSys.data.start
	dialogueSys.speedMod = 1.3
	dialogueSys.send()
	AudioManager.play_random(AudioManager.expie_whine)
	launchflag = true
	pet_count = 0
	pet_timer.stop()


# periodically send a message based on mood
func passivetalk() -> void:
	while true:
		if !gbData.settings.get("mutePassive", false):
			var diaTimerMinimum = float(GlobalVariable.getNumFromString(str(gbData.settings["minDialogueTime"])))

			var diaTimerMaximum = float(GlobalVariable.getNumFromString(str(gbData.settings["maxDialogueTime"])))

			print(diaTimerMinimum, "max")
			print(diaTimerMaximum, "min")
			await get_tree().create_timer(randf_range(float(diaTimerMinimum), float(diaTimerMaximum))).timeout
			if not beingDragged and not isSleeping and not shocked and not $yapHandler.isInteracting():
				dialogueSys.pool = dialogueSys.data.Passive
				match currentEmotion:
					emotionz.normal:
						dialogueSys.pool = dialogueSys.data.Passive
					emotionz.happy:
						dialogueSys.pool = dialogueSys.data.HappyPassive
					emotionz.sad:
						#oops
						dialogueSys.pool = dialogueSys.data.LowPassive
						if moodSys.mood < -30.0:
							dialogueSys.pool = dialogueSys.data.VeryLowPassive


				dialogueSys.speedMod = 1.0
				dialogueSys.send()
		else:
			await get_tree().create_timer(5.0).timeout

func wandering() -> void:
	while get_tree():
		if wander:
			var restChance = randi_range(1, 22)
			if restChance == 1: moveSys.initswithc(moveSys.states.resting)
			await get_tree().create_timer(randi_range(4, 8)).timeout

			var center = GlobalVariable.screenWidth / 2.0
			var ex = moveSys.rigid.global_position.x
			var offset = ex - center
			var th = GlobalVariable.screenWidth * 0.25

			if offset > th:
				moveSys.dir = -1
			elif offset < -th:
				moveSys.dir = 1
			else:
				moveSys.dir = randi_range(-1, 1)

			await get_tree().create_timer(randf_range(.5, 2.0)).timeout
			
			moveSys.dir = 0
		else:
			await get_tree().create_timer(randi_range(4, 8)).timeout

func petReject() -> void:
	dialogueSys.pool = dialogueSys.data.petReject
	dialogueSys.speedMod = 1.2
	dialogueSys.send(2, false)
	AudioManager.play_random(AudioManager.expie_bark, 0.25, 0, 1, true, 0.5, 'exp_pet')
	pass

"""
green because i need a reminder to implement different reactions based on mood
"""
func petLimb(limb: RigidBody2D):
	AudioManager.play_sfx(AudioManager.thudwoosh)
	if randf() < 0.5:
		AudioManager.play_random(AudioManager.expie_bark, 0.25, 0, 1, true, 0.5, 'exp_pet')
	else:
		AudioManager.play_random(AudioManager.expie_whine, 0.25, 0, 1, true, 1, 'exp_pet')
	if isSleeping:
		return

	if moodSys.mood < -40.0:
		petReject()
		return

	#print("I JUST PET THE EXPIE ON HIS ", limb.name)
	faceSys.setEmotion("happy")
	moodSys.mood += 0.5
	moodSys._tempVal(5.0, 13)
	pet_timer.start(pet_timer_inc)
	pet_count += 1
	
	#we can't tween the actual rigid body, its position doesn't update while tweening
	var sprite := limb.get_node_or_null("Sprite2D") as CanvasItem
	if not sprite:
		# if we fuck up, grab the first child node that isn't a CollisionShape2D
		for child in limb.get_children():
			if child is CanvasItem and not child is CollisionShape2D:
				sprite = child
				break

	if sprite:
		var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

		tween.tween_property(sprite, "scale", Vector2(1.07, 0.93), 0.08)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.25)
	
	if not dialogueSys.is_dialogue_playing():
		dialogueSys.pool = dialogueSys.data.pet
		dialogueSys.speedMod = 0.7
		dialogueSys.send(2, false)
		
	await get_tree().create_timer(5).timeout
	faceSys.setEmotion("normal")


#i genuinely dont know what this does
func _on_debugToggle_signal():
	if $"../textParent/DebugText".text == "":
		$"../textParent/DebugText".text = "Test"
	else:
		$"../textParent/DebugText".text = ""


# unused and also this is recycled from my game "Fishy" go play it! It's really good!
# its not and i barely placed top 500 in gmtk with it
func struggle():
	while get_tree():
		randomize()
		await get_tree().create_timer(.1).timeout
		if ragdolled or beingDragged:
			var random_torque = randf_range(-1500.0, 1500.0)
			moveSys.rigidtorso.apply_torque(random_torque)

			var random_force = Vector2(randf_range(-1, 1), randf_range(-1, -2.0))
			moveSys.rigidtorso.apply_central_impulse(random_force * .3)

			await get_tree().create_timer(randf_range(.5, 1.2), false).timeout
