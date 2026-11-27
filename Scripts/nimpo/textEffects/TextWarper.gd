class_name TextWarper
const vowls: Array = ["A", "E", "I", "O", "U", "a", "e", "i", "o", "u"]

const disfigureTalk: Array[String] = [
	"B", "M",
	"F", "V",
	"T", "P", "C", "S",
	"L", "N", "R",
	"J", "C", "Q", "X"
]

const water: Array[String] = [
	"igbh", "blub", "buh", "igbu", "bluh", "buhh",
	"glub", "igbh", "bloo", "buh", "gib", "bluhh",
	"ub", "igblu", "bwah", "gluh", "ib", "blub"
]


# some of these were just the original stupid tag and i just seperated it into 
#different functions except for waterspeech which
##/note for future that static tag silences these errors


##// shortcut

##// public
static func manualTransform(input: String, type: String, chance: float = 0.2) -> String:
	var modInput = input

	#this functions sole perpose was for the text debug menu but 
	#if you can find another use thats probably awesome
	#i know there is 
	if (type.contains("underwater")):
		modInput = waterSpeech(modInput)
	if (type.contains("stutter")):
		modInput = stupify(modInput, chance)
	if (type.contains("disfigure")):
		modInput = disFigureSpeech(modInput, chance)
	if (type.contains("slur")):
		modInput = slurSpeech(modInput, chance)

	return modInput


static func checkText(input: String) -> bool:
	if input.find(input) != -1:
		return true
	else:
		return false


static func checkTag(input: String, speedMod: float) -> Array:
	var string: String = input
	var mod: float = speedMod
#oops
	if checkText("[stutter]"):
		string = string.replace("[stutter]", "")
		string = stupify(string)
		mod -= 0.3
	if checkText("[disfigure]"):
		string = string.replace("[disfigure]", "")
		string = disFigureSpeech(string)
		mod -= 0.1
	return [string, mod]


static func disFigureSpeech(input: String, chance: float = 0.2) -> String:
	var transString: String = ""
	var in_tag: bool = false
	var rng = RandomNumberGenerator.new()
	rng.randomize()


	var poolU: Array[String] = ["A", "E", "I", "O", "U", "H", "C"]
	var poolL: Array[String] = ["a", "e", "i", "o", "u", "h", "c"]

	for i in input.length():
		var c: String = input[i]

		#ignore bbcode
		if c == "[":
			in_tag = true
			transString += c
			continue
		if c == "]":
			in_tag = false
			transString += c
			continue
		if in_tag:
			transString += c
			continue


		if disfigureTalk.has(c.to_upper()) and rng.randf() < chance:
			if c == c.to_upper():
				transString += poolU.pick_random()
			else:
				transString += poolL.pick_random()
		else:
			transString += c

	return transString


static func stupify(input: String, chance: float = 0.2) -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var text = input


	var result = ""
	var words := text.split(" ")

	for wo in words.size():
		var word = words[wo]
		var _ex = ""
		var in_tag = false

		for i in word.length():
			var c = word[i]

			if c == "[":
				in_tag = true
				_ex += c
				continue
			if c == "]":
				in_tag = false
				_ex += c
				continue
			if in_tag:
				_ex += c
				continue

			#stuttering. randomly repeat a letter occasionally
			if i == 0 and rng.randf() < chance:
				_ex += c + "-"

			if rng.randf() < chance:
				pass
				#c = c.to_upper()

			_ex += c

			# extend vowels
			if rng.randf() < chance:
				if vowls.has(c):
					pass
					#ex += c.repeat(extejnd)

		result += _ex
		if wo < words.size() - 1:
			result += " "

	return result


static func slurSpeech(input: String, chance: float = 0.2) -> String:
	var transString: String = ""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var in_tag: bool = false
	var slurLevel: float = 0.0

	for i in input.length():
		var c: String = input[i]

		if c == "[":
			in_tag = true
			transString += c
			continue
		if c == "]":
			in_tag = false
			transString += c
			continue
		if in_tag:
			transString += c
			continue

		if c == " ":
			slurLevel = minf(slurLevel + chance * 0.15, 1.0)
			transString += c
			continue

		if vowls.has(c) and rng.randf() < slurLevel:
			transString += c.repeat(2)
		elif rng.randf() < slurLevel * chance:
			transString += c.to_lower()
		else:
			transString += c

	return transString


static func waterSpeech(input: String) -> String:
	var result: String = ""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	rng.randomize()
	var words := input.split(" ")

	for i in words.size():
		var word: String = words[i]


		if word.begins_with("[") and word.ends_with("]"):
			result += word
		else:
			result += water.pick_random()

		if i < words.size() - 1:
			result += " "

	return result