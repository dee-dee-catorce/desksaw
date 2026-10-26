extends Node
#yap stuff. expies call each other, yap for a bit, then split.


# dd here im trying to read this to the best of my ability and im having trouble

#ill add onto it ina  bit ;)
var callRange := 500.0
var interactCooldown := 80.0
var turnPauseMin := 0.1
var turnPauseMax := 0.5
var tickTime := 0.5

enum yapstates {idle, calling, responding, approaching, progressing, splitting}

var state = yapstates.idle
var partner
var timer: float = 0.0
var walkDir: float = 1.0
var walkFaceDir: float = 1.0
var isCaller: bool = false
var responseAccepted: bool = false

var speaking: bool = false
var speaker
var turnsLeft: int = 0
var finishing: bool = false
var pause: float = 0.0

var nextCall: int = 0
var friendliness: int = 0

func isInteracting() -> bool:
	return state != yapstates.idle

func iconVisible() -> bool:
	return state != yapstates.idle and state != yapstates.splitting

func _ready() -> void:
	friendliness = randi_range(5, 95)
	_yaptick()

func _yaptick():
	while get_tree():
		await get_tree().create_timer(tickTime).timeout
		tick()

func tick():
	match state:
		yapstates.calling:
			_calltick()
		yapstates.responding:
			_respondtick()
		yapstates.approaching:
			timer -= tickTime
			if timer <= 0.0:
				_abort()
		yapstates.progressing:
			if not _partnerprogressing() and not finishing:
				_abort(true)
			elif isCaller or finishing:
				_talktick()
		yapstates.splitting:
			timer -= tickTime
			if timer <= 0.0 or get_parent().beingDragged:
				_clearState()
		yapstates.idle:
			_idletick()

func _idletick():
	if not gbData.settings.get("yapEnabled", true):
		return
	if not _isAvailable(get_parent()):
		return
	if Time.get_ticks_msec() < nextCall:
		return
	var cand = _findCandidate()
	if cand != null:
		_startCall(cand)

func _isAvailable(behavior) -> bool:
	return not behavior.isSleeping and not behavior.shocked and not behavior.beingDragged and not behavior.ragdolled

func _findCandidate():
	var b = get_parent()
	var callerRigid = b.moveSys.rigid
	var facing = -1.0 if b.moveSys.flip else 1.0
	var best = null
	var bestDist = callRange
	for entry in b.detectRange.expiesInRadius.values():
		var other = entry["behavior"]
		var oh = other.get_node_or_null("yapHandler")
		if oh == null or oh.state != yapstates.idle:
			continue
		if not _isAvailable(other):
			continue
		if Time.get_ticks_msec() < oh.nextCall:
			continue
		var otherRigid = other.moveSys.rigid
		var dist = callerRigid.global_position.distance_to(otherRigid.global_position)
		if dist > callRange:
			continue
		if sign(otherRigid.global_position.x - callerRigid.global_position.x) != facing:
			continue
		if dist < bestDist:
			bestDist = dist
			best = other
	return best

func _startCall(cand):
	var b = get_parent()
	var pool = b.dialogueSys.data.get("yapCall", [])
	if pool.is_empty():
		return
	state = yapstates.calling
	partner = cand
	timer = 4.0
	isCaller = true
	responseAccepted = false
	b.wander = false
	b.moveSys.dir = 0.0
	_standUp(b)
	b.moveSys.lookback = false
	b.moveSys.headIk.global_position = b.moveSys.defheadnose.global_position
	b.dialogueSys.setDia(pool.pick_random(), 1.0, 0, true)
	#send the call
	cand.get_node("yapHandler").callReceived(get_parent())

func _calltick():
	if not _isAvailable(get_parent()):
		_abort()
		return
	if not _partnerAlive():
		_abort(true)
		return
	var oh = partner.get_node_or_null("yapHandler")
	if oh == null or not oh.isInteracting():
		_abort(true)
		return
	if not responseAccepted:
		timer -= tickTime
		if timer <= 0.0:
			_abort(true)

#someone called us, decide whether to pick up
func callReceived(caller):
	if (get_parent().moodSys.mood < -50.0):
		caller.get_node("yapHandler").callRejected()
		var pool = get_parent().dialogueSys.data.get("yapReject", [])
		if not pool.is_empty():
			get_parent().dialogueSys.setDia(pool.pick_random(), 1.0, 0, true)
		return
	if state != yapstates.idle:
		caller.get_node("yapHandler").callRejected()
		return
	if not gbData.settings.get("yapEnabled", true) or not _isAvailable(get_parent()) or Time.get_ticks_msec() < nextCall:
		caller.get_node("yapHandler").callRejected()
		return
	_acceptCall(caller)

func _acceptCall(caller):
	var b = get_parent()
	state = yapstates.responding
	partner = caller
	isCaller = false
	responseAccepted = false
	b.wander = false
	_standUp(b)
	#let them know we picked up
	caller.get_node("yapHandler").callAccepted(get_parent())

func callAccepted(responder):
	if state == yapstates.calling and partner == responder:
		responseAccepted = true

func callRejected():
	if state == yapstates.calling:
		# mogged
		await get_tree().create_timer(.5).timeout
		_startSplit(partner)
		var pool = get_parent().dialogueSys.data.get("yapRejectResponse", [])
		if not pool.is_empty():
			get_parent().dialogueSys.setDia(pool.pick_random(), 1.0, 0, true)
		_abort(false)

func _respondtick():
	if not _isAvailable(get_parent()):
		_abort()
		return
	if not _partnerAlive():
		_abort(true)
		return
	var oh = partner.get_node_or_null("yapHandler")
	if oh == null or oh.state != yapstates.calling:
		_abort(true)
		return
	#wait for their line to finish, then head over while responding
	if partner.dialogueSys.is_dialogue_playing():
		return
	_faceTarget(get_parent(), partner.moveSys.rigid)
	get_parent().attention = partner.moveSys.rigid.get_node("Head")
	var pool = get_parent().dialogueSys.data.get("yapResponse", [])
	if not pool.is_empty():
		get_parent().dialogueSys.setDia(pool.pick_random(), 1.0, 0, true)
	state = yapstates.approaching
	timer = 12.0

func _physics_process(_delta: float) -> void:
	var b = get_parent()
	match state:
		yapstates.approaching:
			_approachdrive(b)
		yapstates.splitting:
			_splitdrive(b)
		yapstates.idle:
			pass
		_:
			b.moveSys.dir = 0.0
			b.wander = false

func _approachdrive(b):
	b.wander = false
	if not _partnerAlive():
		_abort(true)
		return
	var rigid = b.moveSys.rigid
	var partnerRigid = partner.moveSys.rigid
	var dx = partnerRigid.global_position.x - rigid.global_position.x
	var adx = abs(dx)
	if adx > 200.0:
		b.moveSys.dir = sign(dx)
	elif adx < 100.0:
		b.moveSys.dir = - sign(dx)
	else:
		b.moveSys.dir = 0.0
		rigid.linear_velocity.x = move_toward(rigid.linear_velocity.x, 0.0, randf_range(400.0, 600.0))
		if abs(rigid.linear_velocity.x) < 10.0 and not b.dialogueSys.is_dialogue_visible():
			_arrived()

func _arrived():
	if partner != null and is_instance_valid(partner):
		partner.get_node("yapHandler").partnerArrived(get_parent())
	_startProgressing(partner)

func partnerArrived(responder):
	if state == yapstates.calling and partner == responder and responseAccepted:
		_startProgressing(responder, true)

func _startProgressing(other, asCaller := false):
	var b = get_parent()
	state = yapstates.progressing
	isCaller = asCaller
	if asCaller:
		speaking = false
		speaker = b
		turnsLeft = randi_range(2, 8)
		finishing = false
		pause = randf_range(turnPauseMin, turnPauseMax)
	_faceTarget(b, other.moveSys.rigid)
	b.attention = other.moveSys.rigid.get_node("Head")
	b.wander = false
	b.moveSys.dir = 0.0

func _partnerprogressing() -> bool:
	if not _partnerAlive():
		return false
	var oh = partner.get_node_or_null("yapHandler")
	return oh != null and (oh.state == yapstates.progressing or oh.state == yapstates.splitting)

func _partnerAlive() -> bool:
	return partner != null and is_instance_valid(partner)

func _endLineDone(behavior) -> bool:
	var rt = behavior.dialogueSys.richtextlabel
	return rt != null and rt.get_total_character_count() > 0 \
		and rt.visible_characters >= rt.get_total_character_count()

func _moodeffect(speaker, other):
	## this wasnt rounded correctly!!!! 
	var f = speaker.get_node("yapHandler").friendliness
	var maxv = max(float(f % 10) / 2.0, 1.0)
	var v = randf_range(1.0, maxv)
	##round it this time

	v = snapped(v, 0.1)
	#higher friendliness means a bigger chance of raising their mood
	var up = randf() * 100.0 < float(f)
	if up:
		other.moodSys.mood += v
	else:
		other.moodSys.mood -= v
	var icon = other.get_parent().get_node_or_null("textParent/TalkIcon")
	if icon != null:
		icon.flashMoodTint(up)

func _say(poolkey):
	var b = get_parent()
	var pool = speaker.dialogueSys.data.get(poolkey, [])
	if pool.is_empty():
		return false
	speaker.dialogueSys.setDia(pool.pick_random(), 1.0, 0, true)
	_moodeffect(speaker, partner if speaker == b else b)
	speaking = true
	return true

func _talktick():
	var b = get_parent()
	if not _partnerAlive():
		_abort(true)
		return
	if not _isAvailable(b):
		_abort()
		return
	if not _isAvailable(partner):
		_abort(true)
		return
	if speaker == null or not is_instance_valid(speaker):
		speaker = b
	if speaking:
		if finishing:
			if _endLineDone(speaker):
				speaking = false
				turnsLeft -= 1
				speaker = partner if speaker == b else b
				_addCooldown(interactCooldown)
				_startSplit(partner)
				return
		elif not speaker.dialogueSys.is_dialogue_visible():
			speaking = false
			turnsLeft -= 1
			speaker = partner if speaker == b else b
			pause = randf_range(turnPauseMin, turnPauseMax)
	else:
		if finishing:
			if partner.dialogueSys.is_dialogue_visible() and not _endLineDone(partner):
				return
			if isCaller:
				return
			if not _say("yapEnd"):
				_addCooldown(interactCooldown)
				_startSplit(partner)
			return
		elif partner.dialogueSys.is_dialogue_visible():
			return
		if pause > 0.0:
			pause -= tickTime
			return
		if turnsLeft <= 0:
			if not finishing:
				finishing = true
				speaker = b
				if _partnerAlive():
					var oh = partner.get_node_or_null("yapHandler")
					if oh != null:
						oh.yapEnding(get_parent())
			if not _say("yapEnd"):
				_finishInteraction()
			return
		if not _say("yapProgress"):
			_finishInteraction()

func _finishInteraction():
	_addCooldown(interactCooldown)
	_startSplit(partner)

func yapEnding(other):
	if state == yapstates.progressing and partner == other:
		finishing = true

func _startSplit(other, cdtime:float = 0.5):
	var b = get_parent()
	var dirx = sign(b.moveSys.rigid.global_position.x - other.moveSys.rigid.global_position.x)
	if dirx == 0:
		dirx = -1.0 if isCaller else 1.0
	var faceDir = dirx
	if randf() < 0.5:
		faceDir = - dirx
	state = yapstates.splitting
	walkDir = dirx
	walkFaceDir = faceDir
	timer = randf_range(cdtime, cdtime*4.0)
	b.attention = null
	b.wander = false
	b.moveSys.dir = dirx
	b.moveSys.skelparent.scale.x = faceDir
	b.moveSys.flip = faceDir == -1.0

func _splitdrive(b):
	b.wander = false
	if b.moveSys.wallDetect.is_colliding():
		_clearState()
		return
	b.moveSys.dir = walkDir
	b.moveSys.skelparent.scale.x = walkFaceDir
	b.moveSys.flip = walkFaceDir == -1.0

func _abort(sayLine := false):
	if sayLine:
		var pool = get_parent().dialogueSys.data.get("yapInterrupt", [])
		if not pool.is_empty():
			get_parent().dialogueSys.setDia(pool.pick_random(), 1.0, 0, true)
	_clearState()
	_addCooldown(10.0)

func _clearState():
	var b = get_parent()
	state = yapstates.idle
	partner = null
	timer = 0.0
	walkDir = 1.0
	walkFaceDir = 1.0
	isCaller = false
	responseAccepted = false
	speaking = false
	speaker = null
	turnsLeft = 0
	finishing = false
	pause = 0.0
	if is_instance_valid(b):
		b.attention = null
		b.wander = true
		b.moveSys.dir = 0.0

func _addCooldown(cooldownSec):
	var actual = randf_range(cooldownSec * 0.5, cooldownSec * 1.5)
	nextCall = Time.get_ticks_msec() + int(actual * 1000.0)

func _standUp(behavior):
	if behavior.moveSys.currstate == behavior.moveSys.states.resting:
		behavior.moveSys.initswithc(behavior.moveSys.states.idle)

func _faceTarget(behavior, target):
	var dirx = sign(target.global_position.x - behavior.moveSys.rigid.global_position.x)
	if dirx == 0:
		return
	behavior.moveSys.skelparent.scale.x = dirx
	behavior.moveSys.flip = dirx == -1.0
