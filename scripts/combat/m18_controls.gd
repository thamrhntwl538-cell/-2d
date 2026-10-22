extends RefCounted
## Device-specific remapping preserves the other device's bindings.
const PATH := "user://folding_library_m18_controls.cfg"
const ACTIONS := ["move_left","move_right","look_up","look_down","jump","attack","dash","spell","heal","interact","pause_game","stage_map","journal","switch_language"]
const KEYS := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"look_up":[KEY_W,KEY_UP],"look_down":[KEY_S,KEY_DOWN],"jump":[KEY_SPACE],"attack":[KEY_J],"dash":[KEY_K],"spell":[KEY_L],"heal":[KEY_H],"interact":[KEY_E],"pause_game":[KEY_ESCAPE],"stage_map":[KEY_M],"journal":[KEY_N,KEY_TAB],"switch_language":[KEY_F2]}
const PAD := {"jump":JOY_BUTTON_A,"attack":JOY_BUTTON_X,"dash":JOY_BUTTON_RIGHT_SHOULDER,"spell":JOY_BUTTON_B,"heal":JOY_BUTTON_Y,"interact":JOY_BUTTON_LEFT_SHOULDER,"pause_game":JOY_BUTTON_START,"stage_map":JOY_BUTTON_BACK,"journal":JOY_BUTTON_LEFT_STICK}
const LABELS := {"move_left":["يسار","Left"],"move_right":["يمين","Right"],"look_up":["أعلى / ضربة علوية","Up / upward slash"],"look_down":["أسفل / ضربة سفلية","Down / downward slash"],"jump":["قفز","Jump"],"attack":["ضرب","Attack"],"dash":["داش","Dash"],"spell":["تقنية","Technique"],"heal":["علاج مطوّل","Hold to heal"],"interact":["تفاعل","Interact"],"pause_game":["إيقاف","Pause"],"stage_map":["خريطة","Map"],"journal":["يوميات","Journal"],"switch_language":["اللغة","Language"]}
var gamepad: bool = false

func setup() -> void:
	defaults()
	var config := ConfigFile.new()
	if config.load(PATH) != OK: return
	for action in ACTIONS:
		for device in ["keyboard","gamepad"]:
			if not config.has_section_key(device,action): continue
			var event: Variant = config.get_value(device,action)
			if event is InputEventKey or event is InputEventJoypadButton:
				_replace_device(action,event)

func defaults() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action,0.3)
		InputMap.action_erase_events(action)
		for code in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
		if PAD.has(action):
			var event := InputEventJoypadButton.new()
			event.button_index = PAD[action]
			InputMap.action_add_event(action,event)
	for item in [["move_left",JOY_AXIS_LEFT_X,-1.0,JOY_BUTTON_DPAD_LEFT],["move_right",JOY_AXIS_LEFT_X,1.0,JOY_BUTTON_DPAD_RIGHT],["look_up",JOY_AXIS_LEFT_Y,-1.0,JOY_BUTTON_DPAD_UP],["look_down",JOY_AXIS_LEFT_Y,1.0,JOY_BUTTON_DPAD_DOWN]]:
		var axis := InputEventJoypadMotion.new()
		axis.axis = item[1]
		axis.axis_value = item[2]
		InputMap.action_add_event(item[0],axis)
		var button := InputEventJoypadButton.new()
		button.button_index = item[3]
		InputMap.action_add_event(item[0],button)
	# Blade clashes have no dedicated button in M18.
	if InputMap.has_action("parry"): InputMap.action_erase_events("parry")

func _replace_device(action: String, event: InputEvent) -> void:
	for old in InputMap.action_get_events(action):
		if (event is InputEventKey and old is InputEventKey) or (event is InputEventJoypadButton and old is InputEventJoypadButton):
			InputMap.action_erase_event(action,old)
	InputMap.action_add_event(action,event)

func rebind(action: String, event: InputEvent) -> bool:
	if action not in ACTIONS or not (event is InputEventKey or event is InputEventJoypadButton): return false
	for other in ACTIONS:
		if other != action and InputMap.action_has_event(other,event): return false
	_replace_device(action,event)
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("keyboard" if event is InputEventKey else "gamepad",action,event)
	return config.save(PATH) == OK

func reset() -> void:
	defaults()
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func hint(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if gamepad and event is InputEventJoypadButton:
			return {JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y",JOY_BUTTON_LEFT_SHOULDER:"LB",JOY_BUTTON_RIGHT_SHOULDER:"RB",JOY_BUTTON_START:"Start",JOY_BUTTON_BACK:"Back",JOY_BUTTON_LEFT_STICK:"L3",JOY_BUTTON_DPAD_LEFT:"←",JOY_BUTTON_DPAD_RIGHT:"→",JOY_BUTTON_DPAD_UP:"↑",JOY_BUTTON_DPAD_DOWN:"↓"}.get(event.button_index,"Pad")
		if not gamepad and event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	return "—"

func rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action in ACTIONS:
		result.append({"action":action,"label_ar":LABELS[action][0],"label_en":LABELS[action][1],"binding":hint(action)})
	return result
