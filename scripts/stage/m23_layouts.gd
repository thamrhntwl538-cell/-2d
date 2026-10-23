extends RefCounted
## M23 adds an explicit room14 boss trial; all M22 geometry remains intact.
const Base=preload("res://scripts/stage/m22_layouts.gd")

static func count() -> int: return 15
static func room(id: int) -> Dictionary: return all_rooms()[clampi(id,1,15)-1]

static func all_rooms() -> Array[Dictionary]:
	var rooms: Array[Dictionary]=Base.all_rooms()
	var tribunal: Dictionary=rooms[13]
	tribunal.compiler_trial={
		"arena_rect":Rect2(1320,1020,1500,420),
		"floor_y":1440.0,
		"intro_threshold_x":1370.0,
		"safe_checkpoint_spawn":Vector2(1040,1440),
		"boss_spawn":Vector2(2450,1440),
		"camera_center":Vector2(2070,1180),
		"camera_zoom":Vector2(.78,.78),
		"gate_rects":[Rect2(1280,1120,32,320),Rect2(2860,1120,32,320)],
		"preview_victory_flag":"preview_compiler_defeated"
	}
	# The existing bench rule checkpoints64px to its right, yielding exactly
	# the declared safe1040 spawn outside the left book gate.
	tribunal.objects.append({"id":"bench_m23_trial","kind":"bench","pos":Vector2(976,1440),"text_key":"bench","title_ar":"استراحة ما قبل المحاكمة","title_en":"Tribunal Rest","m23_trial_bench":true,"checkpoint_spawn":Vector2(1040,1440)})
	tribunal.reading_nooks.append({"id":"rest_bench_m23_trial","object_id":"bench_m23_trial","anchor":Vector2(976,1440),"rect":Rect2(831,1310,290,180),"style":"rest","height":72.0,"requires":[]})
	tribunal.protected_spaces.append(Rect2(826,1230,360,260))
	tribunal.qa_actions.trial_approach=[{"type":"walk","target":Vector2(1040,1440)},{"type":"interact","id":"bench_m23_trial"},{"type":"walk","target":Vector2(1380,1440)}]
	tribunal.qa_paths.trial_approach=[Vector2(1040,1440),Vector2(1380,1440)]
	tribunal.challenge_summary=["Dr. Compiler trial has a safe outside checkpoint, an explicit arena and non-damaging book gates that lock only during the active fight."]
	for exit in tribunal.exits:
		if int(exit.get("target",0))!=15: continue
		exit.combat_preview=false
		exit.requires=["boss_defeated"]
		exit.preview_requires=["preview_compiler_defeated"]
		exit.m23_requires_trial_victory=true
	return rooms
