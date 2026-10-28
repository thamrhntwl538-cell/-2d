extends Node2D
## Isolated playable integration of the supplied Archivist animation reference.
## Sprite art, event windows and sounds are imported unchanged. Encounter health
## and attack selection are tuning defaults; the HTML does not contain game AI.
const Hero = preload("res://scripts/combat/m23_player.gd")
const KeeperSprite = preload("res://scripts/minibosses/m26_archivist_sprite.gd")
const Singing = preload("res://scripts/audio/m26_archive_singing.gd")
const KeeperSound = preload("res://scripts/audio/m26_archivist_sfx.gd")
const HeroSound = preload("res://scripts/audio/m24_soundscape.gd")
const CombatState = preload("res://scripts/combat/m18_combat_state.gd")
const Controls = preload("res://scripts/combat/m18_controls.gd")
const Cleave = preload("res://scripts/combat/m18_projectile.gd")
const Vitals = preload("res://scripts/ui/m22_combat_display.gd")
const BossDisplay = preload("res://scripts/ui/m23_boss_display.gd")
const ArchiveArena = preload("res://scripts/stage/m27_archivist_arena.gd")
const FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const BACKDROP = preload("res://assets/environments/paper_shadows/close_archive.png")
const CATALOG := "res://scenes/minibosses/archivist_reference_m26.tscn"
const FLOOR_Y := 620.0
const ARENA := Rect2(750,200,1190,420)
const MAX_HP := 48
const WALK_SPEED := 105.0
const P1_ORDER := ["slam","sweep","pagestorm","shut","tomes","combo3"]
const P2_ORDER := ["combo5","redpass","sweep","indexlock","burning","pageflip","pagestorm","finale","tomes","combo3","slam","shut"]
const ENDPOINT_X := {"combo3":112.0,"combo5":200.0,"pageflip":360.0}
## World-pixel engagement bands at the approved 194 px character scale.
## The narrow staff bands reach the hero with the first actual blow; teleport
## and grab keep the run-up distance already painted into their source frames.
const ATTACK_SPACING := {
	"slam":{"min":80.0,"max":145.0,"preferred":115.0},
	"sweep":{"min":90.0,"max":190.0,"preferred":145.0},
	"combo3":{"min":145.0,"max":195.0,"preferred":170.0},
	"combo5":{"min":145.0,"max":180.0,"preferred":160.0},
	"redpass":{"min":85.0,"max":170.0,"preferred":130.0},
	"shut":{"min":0.0,"max":155.0,"preferred":115.0},
	"finale":{"min":235.0,"max":305.0,"preferred":270.0},
	"pageflip":{"min":245.0,"max":380.0,"preferred":315.0},
	"pagestorm":{"min":170.0,"max":470.0,"preferred":260.0},
	"tomes":{"min":100.0,"max":400.0,"preferred":290.0},
	"burning":{"min":160.0,"max":390.0,"preferred":235.0},
	"indexlock":{"min":100.0,"max":250.0,"preferred":170.0},
}

class EncounterTarget extends Node2D:
	var encounter: Node2D
	var is_dead: bool:
		get: return encounter.is_dead
	func get_hitbox() -> Rect2: return encounter.get_boss_hurtbox()
	func take_hit(amount: int, _at_x: float, kind: String = "melee") -> bool: return encounter.damage_boss(amount,kind)
	func clash_rect() -> Rect2: return Rect2()
	func on_clash() -> bool: return false

var hero: CharacterBody2D
var keeper: Node2D
var target: EncounterTarget
var singing: Node
var keeper_sound: Node
var soundscape: Node
var combat_state = CombatState.new()
var controls = Controls.new()
var hud: Control
var vitals: Control
var boss_display: Control
var camera: Camera2D
var message: Label
var caption: Label
var focus_hint: Label
var enemies: Array = []
var gameplay_active := true
var paused := false
var boss_active := false
var encounter_started := false
var is_dead := false
var hp := MAX_HP
var phase := 1
var phase_pending := false
var phase_transition_count := 0
var pattern_index := 0
var state := "dormant"
var current_animation := "idle"
var state_time := 0.0
var elapsed := 0.0
var hit_stop_remaining := 0.0
var boss_hit_cooldown := 0.0
var flash_remaining := 0.0
var gate_open := true
var attack_direction := -1
var active_room: Node2D
var _meta: Dictionary = {}
var _last_hitboxes: Array = []
var _hitbox_history: Array[Dictionary] = []
var _animation_history: Array[String] = []
var _grabbed := false
var _grab_slammed := false
var _guard_block_count := 0
var _player_hits := 0
var _boss_damage_events := 0
var _scene_exiting := false
var rage_active := false
var _render_bounds := Rect2(-380,-680,1100,720)
var arena_art: Node2D
var pending_attack := ""
var approach_direction := 0
var attack_start_record: Dictionary = {}
var attack_generation := 0
var _paper_previous: Dictionary = {}
var _paper_previous_hero: Array[Rect2] = []
var _paper_sample_time := -1.0
var _paper_sample_generation := -1
var _paper_sample_facing := 0
var _paper_sample_origin := Vector2.ZERO
var _swept_paper_hits := 0
var _deferred_attack := ""
var _reaction_attack := false

func _create_hero() -> CharacterBody2D: return Hero.new()

func _ready() -> void:
	process_priority = 10 # The unchanged hero resolves sword contact before hazards.
	RenderingServer.set_default_clear_color(Color("070b13"))
	controls.setup()
	_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/minibosses/m26_imported/meta_p2.json"))
	active_room = Node2D.new()
	active_room.name = "IsolatedArchivistRoom"
	add_child(active_room)
	_add_floor()
	arena_art = ArchiveArena.new()
	arena_art.name = "ArchivistCatalogVault"
	active_room.add_child(arena_art)
	combat_state.dash_owned = true
	combat_state.spell_owned = true
	hero = _create_hero()
	hero.name = "ApprovedLanternHero"
	hero.world_ref = self
	hero.position = Vector2(260,FLOOR_Y)
	hero.has_blade = true
	hero.has_dash = true
	hero.has_code_slash = true
	hero.movement_bounds = Vector2(45,1980)
	hero.fall_limit = FLOOR_Y+300
	hero.z_index = 5
	active_room.add_child(hero)
	keeper = KeeperSprite.new()
	keeper.name = "ArchivistBody"
	keeper.position = Vector2(1440,FLOOR_Y-3)
	keeper.z_index = 4
	active_room.add_child(keeper)
	keeper.set_facing(-1)
	keeper.event_crossed.connect(_on_source_event)
	keeper.animation_finished.connect(_on_animation_finished)
	target = EncounterTarget.new()
	target.encounter = self
	target.position = keeper.position
	active_room.add_child(target)
	enemies.append(target)
	camera = Camera2D.new()
	camera.position = Vector2(640,360)
	add_child(camera)
	singing = Singing.new()
	add_child(singing)
	singing.setup(keeper)
	singing.set_listener(hero)
	singing.start_dormant()
	keeper_sound = KeeperSound.new()
	add_child(keeper_sound)
	keeper_sound.setup(keeper)
	soundscape = HeroSound.new()
	add_child(soundscape)
	soundscape.setup(self)
	_make_hud()
	_start_clip("idle",false)
	_refresh_hud()

func _add_floor() -> void:
	var ground := StaticBody2D.new()
	ground.name = "ArchiveFloor"
	ground.collision_layer = 1
	ground.collision_mask = 2
	ground.set_meta("footstep_surface","paper")
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2120,140)
	collision.shape = rect
	collision.position = Vector2(1020,FLOOR_Y+70)
	ground.add_child(collision)
	active_room.add_child(ground)

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CleanEncounterHUD"
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	vitals = Vitals.new()
	vitals.position = Vector2(15,8)
	vitals.size = Vector2(340,146)
	hud.add_child(vitals)
	boss_display = BossDisplay.new()
	boss_display.position = Vector2(340,645)
	boss_display.size = Vector2(600,72)
	hud.add_child(boss_display)
	message = _make_label("",Vector2(260,220),Vector2(760,180),27)
	caption = _make_label("",Vector2(260,600),Vector2(760,42),15)
	focus_hint = _make_label("",Vector2(18,143),Vector2(335,40),14)
	focus_hint.name = "FocusStatus"
	focus_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_hint.visible = false

func _make_label(value: String, at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("ead7b6"))
	label.add_theme_color_override("font_shadow_color",Color("05060a"))
	label.add_theme_constant_override("shadow_offset_y",2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(label)
	return label

func _physics_process(delta: float) -> void:
	if _scene_exiting or paused: return
	elapsed += delta
	boss_hit_cooldown = maxf(0,boss_hit_cooldown-delta)
	flash_remaining = maxf(0,flash_remaining-delta)
	keeper.modulate = Color(1.25,1.1,.95) if flash_remaining>0 else Color.WHITE
	if hit_stop_remaining>0:
		hit_stop_remaining = maxf(0,hit_stop_remaining-delta)
		if hit_stop_remaining<=0 and hero.hp>0: gameplay_active = true
		_refresh_hud()
		return
	if hero.hp<=0:
		_refresh_hud()
		return
	if not encounter_started:
		keeper.set_facing(1 if hero.position.x>keeper.position.x else -1)
		keeper.advance(delta)
		camera.position.x = clampf(hero.position.x,640,1380)
		if absf(hero.position.x-keeper.position.x)<=230: start_encounter()
	elif is_dead:
		keeper_sound.advance(delta)
		keeper.advance(delta)
	elif gameplay_active:
		camera.position.x = lerpf(camera.position.x,1345.0,1.0-exp(-8.0*delta))
		keeper_sound.advance(delta)
		keeper.advance(delta)
		if state=="walk":
			_update_approach(delta)
		else:
			state_time = maxf(0,state_time-delta)
		if state in ["intro","idle"] and state_time<=0:
			if state=="intro": _set_idle(.18)
			elif phase_pending: _begin_transform()
			else: _next_attack()
		if _grabbed:
			var pose: Dictionary = keeper.get_pose()
			hero.position = keeper.position+Vector2((float(pose.get("x",0))+90)*attack_direction,-130.0)*keeper.visual_scale
			hero.velocity = Vector2.ZERO
			# The successful grab alone locks control until the source release event.
			hero.set_physics_process(false)
		_resolve_source_hits(delta)
	target.position = keeper.position
	_refresh_hud()
	queue_redraw()

func start_encounter() -> void:
	if encounter_started or is_dead or hero.hp<=0: return
	encounter_started = true
	boss_active = true
	gate_open = false
	singing.stop_for_encounter() # Exact boundary; no fade or distance reactivation.
	hero.movement_bounds = Vector2(ARENA.position.x+24,ARENA.end.x-24)
	hero.position.x = clampf(hero.position.x,hero.movement_bounds.x,hero.movement_bounds.y)
	state = "intro"
	state_time = .45
	# He was already present and singing; the fight never makes him vanish.
	_start_clip("idle")
	_refresh_hud()

func _start_clip(name: String, with_sound: bool = true) -> void:
	attack_generation += 1
	reset_hazard_sweep()
	current_animation = name
	var use_phase := 2 if phase==2 or name=="p2tr" else 1
	var speed := 1.15 if phase==2 and str(_meta.get(name,{}).get("category","")) in ["p1","p2"] else 1.0
	rage_active = phase==2 and hp<float(MAX_HP)*.15
	# The HTML tooltip specifies <15% health, 30% extra animation speed. Latch
	# at the next clip so an already visible wind-up never shortens mid-swing.
	if rage_active: speed *= 1.3
	keeper.playback_speed = speed
	keeper.set_animation(name,use_phase,true)
	if with_sound: keeper_sound.play_animation(name,use_phase,_meta.get(name,{}),speed)
	else: keeper_sound.stop_all()
	_animation_history.append(name)
	_last_hitboxes.clear()
	_grab_slammed = false

func _set_idle(seconds: float) -> void:
	state = "idle"
	state_time = seconds
	keeper.set_facing(1 if hero.position.x>keeper.position.x else -1)
	_start_clip("idle")

func _next_attack() -> void:
	if pending_attack.is_empty():
		var order: Array = P2_ORDER if phase==2 else P1_ORDER
		pending_attack = str(order[pattern_index%order.size()])
	_begin_attack()

func _attack_band(name: String) -> Dictionary:
	var band: Dictionary = ATTACK_SPACING.get(name,{"min":80.0,"max":180.0,"preferred":130.0}).duplicate()
	var ratio: float = keeper.visual_scale / (194.0/350.0)
	for key in ["min","max","preferred"]: band[key] = float(band[key])*ratio
	return band

func _approach_limits(name: String, facing: int) -> Vector2:
	var end_shift: float = float(ENDPOINT_X.get(name,0))*keeper.visual_scale*facing
	# Reserve room for the baked endpoint before committing a combo/teleport.
	return Vector2(ARENA.position.x+75.0-minf(0,end_shift),ARENA.end.x-75.0-maxf(0,end_shift))

func _attack_in_range(name: String) -> bool:
	var gap := absf(hero.position.x-keeper.position.x)
	var band := _attack_band(name)
	var face := 1 if hero.position.x>keeper.position.x else -1
	var limits := _approach_limits(name,face)
	return gap>=float(band.min)-.01 and gap<=float(band.max)+.01 and keeper.position.x>=limits.x-.01 and keeper.position.x<=limits.y+.01

func reset_ai_intent() -> void:
	pending_attack = ""
	_deferred_attack = ""
	_reaction_attack = false
	approach_direction = 0

func _try_close_response() -> bool:
	if pending_attack.is_empty() or _reaction_attack: return false
	var band := _attack_band(pending_attack)
	if absf(hero.position.x-keeper.position.x)>=float(band.min): return false
	# A faster hero can keep chasing a retreating book. Respond with an
	# existing attack which reaches that distance, then retry the planned move.
	for response in ["shut","sweep","pagestorm"]:
		if response!=pending_attack and _attack_in_range(response):
			_deferred_attack = pending_attack
			pending_attack = response
			_reaction_attack = true
			_begin_attack()
			return true
	return false

func _update_approach(delta: float) -> void:
	if phase_pending:
		_begin_transform()
		return
	if pending_attack.is_empty():
		_next_attack()
		return
	if _attack_in_range(pending_attack):
		_begin_attack()
		return
	if _try_close_response(): return
	# Only approach tracks the hero. Actual attacks retain their captured facing.
	attack_direction = 1 if hero.position.x>keeper.position.x else -1
	keeper.set_facing(attack_direction)
	var band := _attack_band(pending_attack)
	var limits := _approach_limits(pending_attack,attack_direction)
	var goal := clampf(hero.position.x-attack_direction*float(band.preferred),limits.x,limits.y)
	approach_direction = int(signf(goal-keeper.position.x))
	keeper.position.x = move_toward(keeper.position.x,goal,WALK_SPEED*delta)
	state_time = absf(goal-keeper.position.x)/WALK_SPEED
	if _attack_in_range(pending_attack): _begin_attack()

func _begin_attack() -> void:
	if phase_pending:
		_begin_transform()
		return
	if pending_attack.is_empty():
		var order: Array = P2_ORDER if phase==2 else P1_ORDER
		pending_attack = str(order[pattern_index%order.size()])
	if not _attack_in_range(pending_attack):
		if _try_close_response(): return
		if state!="walk":
			state = "walk"
			_start_clip("walk")
		state_time = absf(hero.position.x-keeper.position.x)/WALK_SPEED
		return
	var name := pending_attack
	attack_direction = 1 if hero.position.x>keeper.position.x else -1
	keeper.set_facing(attack_direction)
	attack_start_record = {"name":name,"gap":absf(hero.position.x-keeper.position.x),"origin":keeper.position,"target":hero.position,"facing":attack_direction,"band":_attack_band(name),"reaction":_reaction_attack,"deferred":_deferred_attack}
	pending_attack = ""
	approach_direction = 0
	if not _reaction_attack: pattern_index += 1
	state = "attack"
	_start_clip(name)

func _begin_transform() -> void:
	reset_ai_intent()
	phase_pending = false
	phase = 2
	phase_transition_count += 1
	pattern_index = 0
	state = "transform"
	_release_grab()
	_start_clip("p2tr")

func _on_animation_finished() -> void:
	if not encounter_started or paused: return
	if current_animation=="death":
		boss_active = false
		gate_open = true
		state = "victory"
		keeper_sound.stop_all()
		return
	if state in ["attack","transform","intro","hurt"]:
		# Artwork contains its own lunge/teleport: commit only the endpoint after
		# completion, so the following idle starts at the visible ending location.
		keeper.position.x = clampf(keeper.position.x+float(ENDPOINT_X.get(current_animation,0))*keeper.visual_scale*attack_direction,ARENA.position.x+75,ARENA.end.x-75)
		_release_grab()
		if _reaction_attack:
			pending_attack = _deferred_attack
			_deferred_attack = ""
			_reaction_attack = false
		if phase_pending: _begin_transform()
		else: _set_idle(.18 if phase==2 else .30)

func _on_source_event(event_name: String) -> void:
	if event_name=="slam_damage" and _grabbed and not _grab_slammed:
		_grab_slammed = true
		hero.set_physics_process(true)
		hero.hurt(2,keeper.position.x)
		hero.set_physics_process(false)
	if event_name=="release": _release_grab()

func _release_grab() -> void:
	if not _grabbed: return
	_grabbed = false
	if is_instance_valid(hero):
		hero.set_physics_process(true)
		hero.position.y = minf(hero.position.y,FLOOR_Y-10)
		hero.velocity = Vector2(attack_direction*160,-180)

func reset_hazard_sweep() -> void:
	_paper_previous.clear()
	_paper_previous_hero.clear()
	_paper_sample_time = -1.0
	_paper_sample_generation = -1
	_paper_sample_facing = 0

func _segment_hits_box(start: Vector2, finish: Vector2, half_size: Vector2) -> bool:
	var direction := finish-start
	var enter := 0.0
	var leave := 1.0
	for axis in range(2):
		if absf(direction[axis])<.000001:
			if start[axis]<-half_size[axis] or start[axis]>half_size[axis]: return false
		else:
			var near: float = (-half_size[axis]-start[axis])/direction[axis]
			var far: float = (half_size[axis]-start[axis])/direction[axis]
			if near>far:
				var swap := near
				near = far
				far = swap
			enter = maxf(enter,near)
			leave = minf(leave,far)
			if enter>leave: return false
	return true

func _paper_crossed_hero(previous: Rect2, current: Rect2, boxes: Array[Rect2]) -> bool:
	if boxes.size()!=_paper_previous_hero.size(): return false
	# Relative motion tests each actual hero box separately. Sweeping one
	# rectangle per sheet never fills the harmless gaps between the paper fan.
	for index in range(boxes.size()):
		var old_hero := _paper_previous_hero[index]
		var new_hero := boxes[index]
		var half_size := previous.size.max(current.size)*.5+old_hero.size.max(new_hero.size)*.5
		if _segment_hits_box(previous.get_center()-old_hero.get_center(),current.get_center()-new_hero.get_center(),half_size): return true
	return false

func _resolve_source_hits(delta: float = 0.0) -> void:
	_last_hitboxes = _runtime_hitboxes()
	var current_time: float = keeper.animation_time
	var hero_boxes: Array[Rect2] = hero.get_hurtboxes()
	var continuous := delta>0 and _paper_sample_generation==attack_generation and _paper_sample_facing==attack_direction
	continuous = continuous and current_time>=_paper_sample_time and current_time-_paper_sample_time<=delta*keeper.playback_speed+.0001
	continuous = continuous and keeper.global_position.distance_to(_paper_sample_origin)<.01
	if continuous and not _paper_previous_hero.is_empty():
		continuous = hero_boxes[0].get_center().distance_to(_paper_previous_hero[0].get_center())<=1200.0*delta+24.0
	var next_papers: Dictionary = {}
	for entry in _last_hitboxes:
		var rect: Rect2 = entry.get("rect",Rect2())
		var kind := str(entry.get("kind",entry.get("k","n")))
		var overlap := _hero_overlaps(rect)
		var crossed := false
		if kind=="proj":
			var id := str(entry.get("id",""))
			if continuous and _paper_previous.has(id): crossed = _paper_crossed_hero(_paper_previous[id],rect,hero_boxes)
			next_papers[id] = rect
		if not overlap and not crossed: continue
		if kind=="grab":
			if not _grabbed and hero.invulnerable<=0:
				_grabbed = true
				_grab_slammed = false
			continue
		if _grabbed and current_animation=="finale": continue
		var amount := 2 if kind=="red" or current_animation in ["slam","redpass","combo5"] else 1
		var before: int = hero.hp
		hero.hurt(amount,rect.get_center().x)
		if hero.hp<before:
			_player_hits += 1
			if kind=="proj" and crossed and not overlap: _swept_paper_hits += 1
			_hitbox_history.append({"animation":current_animation,"phase":phase,"kind":kind,"damage":amount,"source_time":keeper.get_snapshot().get("time",0),"paper_id":entry.get("id",""),"volley":entry.get("volley",-1),"sheet":entry.get("sheet",-1),"contact":"sweep" if crossed and not overlap else "overlap"})
	# Visible sheets are not consumed by an invulnerable contact or by a hit
	# from a different sheet. The shared hero.hurt() grace remains authoritative.
	_paper_previous = next_papers
	_paper_previous_hero = hero_boxes
	_paper_sample_time = current_time
	_paper_sample_generation = attack_generation
	_paper_sample_facing = attack_direction
	_paper_sample_origin = keeper.global_position

func _hero_overlaps(rect: Rect2) -> bool:
	for box in hero.get_hurtboxes():
		if rect.intersects(box): return true
	return false

func _source_hit(result: Array, rectangle: Rect2, kind: String) -> void:
	# Includes exterior FX restored from the exact supplied HTML. A collider
	# never extends beyond the current rendered art or into a harmless glow.
	var clipped := rectangle.intersection(_render_bounds)
	if not clipped.has_area(): return
	var first: Vector2 = keeper.to_global(clipped.position*Vector2(float(attack_direction),1)*keeper.visual_scale)
	var opposite: Vector2 = keeper.to_global(clipped.end*Vector2(float(attack_direction),1)*keeper.visual_scale)
	result.append({"rect":Rect2(first,opposite-first).abs(),"kind":kind,"source_rect":clipped})

func _ease_out(value: float) -> float:
	return 1.0-pow(1.0-clampf(value,0,1),3)

func _smooth(value: float) -> float:
	var t := clampf(value,0,1)
	return t*t*(3-2*t)

func _hash2(a: float,b: float) -> float:
	var n := (a*17.31+b*91.7+3.3)*127.1+311.7
	return fposmod(sin(n)*43758.5453,1.0)

func _source_wave(result: Array, x0: float, age: float, speed: float, maximum: float, height: float, kind: String = "wave") -> void:
	if age<=0: return
	var x := x0+speed*_ease_out(age/1.1)*1.1
	var life := 1.0-clampf((x-x0)/(maximum-x0),0,1)
	if life<=.03: return
	# Four narrow slices follow the visible wedge, rather than the reference's
	# static half-screen demonstration rectangle.
	_source_hit(result,Rect2(x-146,-8,52,8),kind)
	_source_hit(result,Rect2(x-94,-height*.35,55,height*.35),kind)
	_source_hit(result,Rect2(x-39,-height*.72,39,height*.72),kind)
	_source_hit(result,Rect2(x,-height*.85,21,height*.85),kind)

func _source_ring(result: Array, center: Vector2, radius: float, thickness: float, kind: String) -> void:
	if radius<5: return
	# The active ring rim is sampled densely enough to overlap a narrow player
	# collider. Its empty center and harmless glow never deal damage.
	var count := maxi(24,int(ceil(TAU*radius/maxf(12,thickness))))
	for i in range(count):
		var point := center+Vector2(cos(TAU*i/count),sin(TAU*i/count))*radius
		_source_hit(result,Rect2(point-Vector2.ONE*thickness*.5,Vector2.ONE*thickness),kind)

func _runtime_hitboxes() -> Array:
	var result: Array = []
	var snapshot: Dictionary = keeper.get_snapshot()
	_render_bounds = snapshot.get("draw_frame_rect",Rect2(0,0,1100,720))
	_render_bounds.position -= KeeperSprite.SOURCE_PIVOT
	var pose: Dictionary = keeper.get_pose()
	var u := float(pose.get("u",0))
	var duration := float(_meta.get(current_animation,{}).get("duration",1))
	# The supplied metadata rectangles illustrate attack categories. Their
	# fixed projectile/wall areas do not track the moving supplied art. Keep the
	# melee windows and make actual hazards follow the exact HTML FX equations.
	for source in keeper.get_active_hitboxes():
		var kind := str(source.get("kind",source.get("k","n")))
		if kind=="n" and current_animation not in ["tomes","shut"]:
			_source_hit(result,source.rect,kind)
	if current_animation=="slam":
		_source_wave(result,256,(u-.46)*duration,520,780,88)
	elif current_animation=="combo3":
		_source_wave(result,370,(u-.76)*duration,520,840,90)
	elif current_animation=="combo5":
		_source_wave(result,480,(u-.66)*duration,520,960,100)
		_source_wave(result,400,(u-.66)*duration,-520,-300,80)
	elif current_animation=="redpass":
		if u>=.64 and u<=.78: _source_hit(result,Rect2(100,-200,220,200),"red")
		_source_wave(result,270,(u-.64)*duration,640,1000,120,"red")
	elif current_animation=="pagestorm":
		for volley in range(3):
			var age: float = (u-float([.40,.54,.68][volley]))*duration
			if age<0: continue
			for i in range(7):
				var angle := deg_to_rad(-24+48.0*i/6+(volley-1)*5)
				var speed := 780+120*_hash2(i,volley)
				var x := 140+cos(angle)*speed*age
				var y := -200+sin(angle)*speed*age+40*age*age
				if x<=995:
					var count := result.size()
					_source_hit(result,Rect2(x-10,y-14,20,28),"proj")
					if result.size()>count:
						result[-1]["id"] = "%d:%d:%d" % [attack_generation,volley,i]
						result[-1]["volley"] = volley
						result[-1]["sheet"] = i
	elif current_animation=="tomes":
		for i in range(5):
			var age := (u-(.50+i*.05))*duration
			if age<=0 or age>.476: continue
			var x: float = [210,370,530,700,-190][i]
			var y := -720+720*pow(age/.24,2) if age<.24 else 0.0
			_source_hit(result,Rect2(x-56,y-55,112,63),"n")
	elif current_animation=="indexlock":
		var rise := _ease_out((u-.3)/.1)
		var sink := 1.0-clampf((u-.78)/.12,0,1)
		var close := _smooth((u-.4)/.32)
		var height := 430*rise*sink
		if height>5:
			for x in [lerpf(700,560,close),lerpf(-520,-380,close)]:
				_source_hit(result,Rect2(x-34,-height,68,height),"wall")
	elif current_animation=="burning":
		for i in range(4):
			var ignition := .42+i*.035
			var age := (u-ignition)*duration
			if u<ignition+.02 or u>.85: continue
			var height := 142*_ease_out(age/.3)*(1.0-clampf((u-.82)/.1,0,1))
			_source_hit(result,Rect2(260+i*160-52,-height,104,height),"fire")
	elif current_animation=="shut" and u>=.78 and u<=.90:
		var age := (u-.76)*duration
		_source_ring(result,Vector2(10,-200),330*_ease_out(age/.5),24,"n")
	elif current_animation=="p2tr" and u>=.47 and u<=.60:
		var age := (u-.46)*duration
		var radius := 800*_ease_out(age/.8)
		var height := 60*_ease_out(age/.8)
		for x in [-radius,radius]:
			_source_hit(result,Rect2(x-18,-height,36,height),"wave")
	elif current_animation=="finale":
		if u>=.4 and u<=.52:
			var hand := Vector2(float(pose.get("x",0))+270,-156)
			_source_hit(result,Rect2(hand-Vector2(48,48),Vector2(96,96)),"grab")
		if u>=.76 and u<=.86:
			var age := (u-.75)*duration
			_source_ring(result,Vector2(float(pose.get("x",0))+60,-180),340*_ease_out(age/.6),24,"red")
	return result

func get_boss_hurtbox() -> Rect2:
	var origin := keeper.position
	var pose: Dictionary = keeper.get_pose()
	if not pose.is_empty():
		origin += Vector2(float(pose.get("x",0))*attack_direction,-float(pose.get("y",0)))*keeper.visual_scale
	return Rect2(origin+Vector2(-67,-194),Vector2(134,194))

func _guarded() -> bool:
	if current_animation!="shut": return false
	var snapshot: Dictionary = keeper.get_snapshot()
	var u: float = float(snapshot.get("time",0))/maxf(.001,float(snapshot.get("duration",1)))
	return u>=.24 and u<.74

func _untargetable() -> bool:
	var snapshot: Dictionary = keeper.get_snapshot()
	var u: float = float(snapshot.get("time",0))/maxf(.001,float(snapshot.get("duration",1)))
	if state=="intro" or state=="dormant": return true
	if current_animation=="p2tr" and u<.72: return true
	return current_animation=="pageflip" and u>=.2 and u<.44

func damage_boss(amount: int, kind: String = "melee") -> bool:
	if not encounter_started or is_dead or not gameplay_active or amount<=0 or boss_hit_cooldown>0 or _untargetable(): return false
	if _guarded():
		_guard_block_count += 1
		keeper_sound.play_extra("guard_hit_block")
		return false
	hp = maxi(0,hp-amount)
	boss_hit_cooldown = .07
	flash_remaining = .055
	_boss_damage_events += 1
	play_sfx("hit")
	if hp<=0:
		reset_ai_intent()
		is_dead = true
		state = "death"
		_release_grab()
		singing.stop_for_encounter()
		_start_clip("death")
	elif hp<=MAX_HP/2 and phase==1:
		phase_pending = true
		if state in ["idle","walk","hurt"]: _begin_transform()
	elif kind=="melee" and state=="idle":
		state = "hurt"
		_start_clip("hurt")
	_refresh_hud()
	return true

func hero_strike(direction: String, facing: int) -> void:
	if not gameplay_active or hero.active_strike_time<=0 or is_dead: return
	var id := target.get_instance_id()
	if hero.hit_targets.has(id): return
	var rect: Rect2 = hero.strike_rect(direction,facing)
	if rect.has_area() and rect.intersects(get_boss_hurtbox()):
		if _guarded():
			hero.hit_targets[id] = true
			keeper_sound.play_extra("guard_hit_block")
			_guard_block_count += 1
			if direction=="down": hero.pogo()
			return
		if damage_boss(1,"melee"):
			hero.hit_targets[id] = true
			hero.gain_energy(combat_state.energy_per_hit())
			if direction=="down": hero.pogo()
			hit_stop_remaining = .035
			gameplay_active = false
			combat_changed()

func cast_code_slash(point: Vector2, direction: int) -> void:
	var projectile := Cleave.new()
	active_room.add_child(projectile)
	projectile.setup(self,point,direction)
	play_sfx("spell")
	combat_changed()

func emit_burst(point: Vector2, color: Color, amount: int) -> void:
	if not is_instance_valid(active_room): return
	var particles := CPUParticles2D.new()
	particles.position = point
	particles.amount = clampi(amount,3,12)
	particles.lifetime = .24
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0,-1)
	particles.spread = 145
	particles.gravity = Vector2(0,200)
	particles.initial_velocity_min = 35
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 1.3
	particles.scale_amount_max = 2.8
	particles.color = color
	particles.z_index = 12
	active_room.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true

func play_sfx(cue: String) -> void:
	# M25's soundscape explicitly removes every hero vocal cue and vocal layer.
	if is_instance_valid(soundscape): soundscape.play_event(cue)

func show_tip(_value: String) -> void: pass
func combat_changed() -> void: _refresh_hud()
func player_fell() -> void: hero.hurt(6,hero.position.x)

func on_player_death() -> void:
	gameplay_active = false
	hit_stop_remaining = 0
	_release_grab()
	singing.stop_for_encounter()
	keeper_sound.stop_all()
	keeper.set_playing(false)
	_refresh_hud()

func set_paused(value: bool) -> void:
	reset_hazard_sweep()
	paused = value
	gameplay_active = not value and hero.hp>0 and hit_stop_remaining<=0
	singing.set_paused(value)
	keeper_sound.set_paused(value)
	if is_instance_valid(arena_art): arena_art.set_paused(value)
	_refresh_hud()

func _refresh_hud() -> void:
	if not is_instance_valid(vitals): return
	var context := {"hp":hero.hp,"max_hp":6,"energy":hero.energy,"max_energy":99,"wallet":0,"equipped":[],"spell_owned":true}
	context.merge(healing_status_context(),true)
	vitals.update_context(context,"ar")
	_update_focus_hint("ar")
	boss_display.update_context({"visible":encounter_started and not is_dead,"name_ar":"أمين الأرشيف","name_en":"The Archivist","hp":hp,"max_hp":MAX_HP,"phase":phase},"ar")
	# The encounter stays clean: only the player vitals remain on screen.
	boss_display.visible = false
	message.visible = paused or hero.hp<=0 or state=="victory" or not encounter_started
	caption.visible = message.visible
	if paused:
		message.text = "متوقف مؤقتًا"
		caption.text = "P / Start: متابعة · R: محاولة جديدة · Esc / Back: استوديو الحركات"
	elif hero.hp<=0:
		message.text = "انطفأت الشعلة"
		caption.text = "R / Y: محاولة جديدة · Esc / Back: استوديو الحركات"
	elif state=="victory":
		message.text = "سكنت الصفحات"
		caption.text = "R / Y: تجربة جديدة · Esc / Back: استوديو الحركات"
	elif not encounter_started:
		message.text = "أمين الأرشيف"
		caption.text = "اقترب من صوته · A/D: حركة · Space: قفز · J: سيف · K: داش · L: تقنية · H: علاج"

func healing_status_context() -> Dictionary:
	var reason := ""
	if not is_instance_valid(hero): return {"healing":false,"heal_progress":0.0,"heal_block_reason":""}
	if Input.is_action_pressed("heal") and not hero.healing:
		if hero.heal_release_required: reason = "release"
		elif hero.hp>=hero.max_hp: reason = "full"
		elif hero.energy<Hero.ACTION_COST: reason = "energy"
		elif not hero.is_on_floor(): reason = "airborne"
		elif absf(Input.get_axis("move_left","move_right"))>.05: reason = "moving"
		elif hero.attack_time>0 or hero.dash_time>0 or hero.hurt_time>0 or hero.spell_cooldown>0: reason = "busy"
	var duration := 1.141*combat_state.focus_duration_multiplier()
	return {"healing":hero.healing,"heal_progress":clampf(1.0-hero.heal_time/duration,0,1) if hero.healing else 0.0,"heal_block_reason":reason}

func _update_focus_hint(locale: String) -> void:
	if not is_instance_valid(focus_hint): return
	focus_hint.visible = Input.is_action_pressed("heal") and not paused and hero.hp>0
	if not focus_hint.visible: return
	var arabic := locale=="ar"
	var status := healing_status_context()
	var binding := controls.hint("heal")
	if hero.healing:
		focus_hint.text = "استمر بالضغط لإكمال العلاج" if arabic else "Keep holding to complete Focus"
	else:
		match str(status.heal_block_reason):
			"release": focus_hint.text = ("أفلت %s ثم اضغطه مطولًا" if arabic else "Release %s, then hold again") % binding
			"energy": focus_hint.text = "تحتاج إلى 33 وهج · أصب العدو بالسيف" if arabic else "Needs 33 glow · Strike enemies with your blade"
			"full": focus_hint.text = "فوانيس الصحة ممتلئة" if arabic else "Health lanterns are full"
			"airborne": focus_hint.text = "اهبط واثبت لبدء العلاج" if arabic else "Land and stand still to Focus"
			"moving": focus_hint.text = "اثبت لبدء العلاج" if arabic else "Stand still to Focus"
			_: focus_hint.text = "انتظر انتهاء الحركة ثم استمر بالضغط" if arabic else "Keep holding after the current action"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: _return_to_catalog()
			KEY_P: set_paused(not paused)
			KEY_R: get_tree().reload_current_scene()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_BACK: _return_to_catalog()
			JOY_BUTTON_START: set_paused(not paused)
			JOY_BUTTON_Y:
				if hero.hp<=0 or state=="victory" or paused: get_tree().reload_current_scene()

func _return_to_catalog() -> void:
	_scene_exiting = true
	singing.stop_for_room_exit()
	keeper_sound.stop_all()
	soundscape.stop_all()
	get_tree().change_scene_to_file(CATALOG)

func get_trial_snapshot() -> Dictionary:
	return {"isolated_trial":true,"writes_save":false,"state":state,"animation":current_animation,"encounter_started":encounter_started,"singing":singing.is_singing(),"singing_latched":singing.encounter_started,"hp":hp,"max_hp":MAX_HP,"hero_hp":hero.hp,"hero_energy":hero.energy,"phase":phase,"phase_transitions":phase_transition_count,"phase_pending":phase_pending,"rage":rage_active,"paused":paused,"gate_open":gate_open,"is_dead":is_dead,"keeper_position":keeper.position,"hero_position":hero.position,"direction":attack_direction,"source":keeper.get_snapshot(),"animation_history":_animation_history.duplicate(),"player_hits":_player_hits,"boss_damage_events":_boss_damage_events,"guard_blocks":_guard_block_count,"hit_history":_hitbox_history.duplicate(true),"grabbed":_grabbed,"runtime_hitboxes":_last_hitboxes.duplicate(true),"pending_attack":pending_attack,"approach_direction":approach_direction,"attack_start_record":attack_start_record.duplicate(true),"paper_generation":attack_generation,"previous_paper_count":_paper_previous.size(),"swept_paper_hits":_swept_paper_hits}

func _draw() -> void:
	draw_texture_rect(BACKDROP,Rect2(0,-135,2040,900),false,Color(.56,.57,.63))
	draw_rect(Rect2(0,FLOOR_Y,2040,150),Color("161922"))
	draw_line(Vector2(0,FLOOR_Y),Vector2(2040,FLOOR_Y),Color("9c8667"),3,true)
	for x in range(0,2040,100):
		draw_line(Vector2(x,FLOOR_Y+7),Vector2(x+90,FLOOR_Y+7),Color("544733"),2,true)
	if not gate_open:
		for x in [ARENA.position.x-30,ARENA.end.x]:
			draw_rect(Rect2(x,200,28,FLOOR_Y-200),Color("14151b"))
			draw_line(Vector2(x+14,200),Vector2(x+14,FLOOR_Y),Color("655034"),3,true)

func _exit_tree() -> void:
	_scene_exiting = true
	if is_instance_valid(singing): singing.stop_for_room_exit()
	if is_instance_valid(keeper_sound): keeper_sound.stop_all()
	if is_instance_valid(soundscape): soundscape.stop_all()
