extends Node

"""
script that terramogs old behaviour.gd

it IS mostly just behaviour.gd but still


"""

#referebces for systems to be used by this script

@onready var faceSys = $faceHandler
@onready var moodSys = $moodHandler
@onready var moveSys = $movementHandler
@onready var sleepHandler = $sleepManager
@onready var hungerHandler = $hungerHandler
@onready var dialogueSys = $dialogue
@onready var detectRange = $detRadius
@onready var statUpd = $statWatcher
@onready var settings = gbData.settings

#f;oaafsd
@onready var mainBody = moveSys.rigid


var attention: Node2D = null
var isSleeping := false
var shocked := false

var currentEmotion = emotionz.normal
var petId := ""

#yes. i finally made a variable for this it only took 4 months post release



enum emotionz {

	normal, sad, sleep, tired, scared, panic, happy

}
func _ready() -> void:
        if petId == "":
            var skinName = GlobalVariable.userSkinPath.substr(0, len(GlobalVariable.userSkinPath) - 1)

            skinName = skinName.substr(skinName.rfind("/") + 1)

            petId = gbData.addPet(skinName)

        get_parent().get_parent().set_meta("itemName", petId)


        #call setup
        _initalSpawn()


func _initalSpawn() -> void:
    faceSys.setEmotion("default")
    

    """
    the first course of action is removing all of this shit because
    idk what i was thinking when designing this section
    """



    
    moveSys.rigid.global_position.x = float(GlobalVariable.screenWidth) / 2
    moveSys.rigid.global_position.y = float(GlobalVariable.screenHeight) * 2

    moodSys.loadFromSave(petId)
    hungerHandler.loadFromSave(petId)
    sleepHandler.loadFromSave(petId)




# ragdoll func