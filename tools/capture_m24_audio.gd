extends SceneTree
## Configured sound-review fixture, visibly labeled; never combat evidence.
const Review=preload("res://scripts/minibosses/m24_character_review.gd")
const BellSound=preload("res://scripts/audio/m24_soundscape.gd")
const BellMusic=preload("res://scripts/audio/m24_bell_music.gd")
class AudioFixture:
	extends Node2D
	var gameplay_active:=true
	var paused:=false
	var boss_active:=true
	var current_room:=12
var fixture:Node2D
var review:Node2D
var sounds:Node
var music:Node
var failures:Array[String]=[]

func _initialize() -> void:call_deferred("run")

func step(seconds:float) -> void:
	for frame in roundi(seconds*60.0):
		await physics_frame
		await process_frame

func event(cue:String,caption:String,seconds:float) -> void:
	review.mode.text="عينة مضبوطة: "+caption
	if not sounds.play_at(cue,Vector2(640,360)):failures.append("Audio event rejected: "+cue)
	await step(seconds)

func run() -> void:
	root.size=Vector2i(1280,720)
	fixture=AudioFixture.new()
	root.add_child(fixture)
	review=Review.new()
	fixture.add_child(review)
	review.set_page("scale")
	review.title.text="حارس الجرس · مراجعة الصوت داخل Godot"
	review.subtitle.text="تشغيل عينات صوتية مضبوطة · موسيقى أصلية وأصوات الجرس · ليس تسجيل قتال"
	review.mode.text="الموسيقى الأصلية فقط"
	sounds=BellSound.new();fixture.add_child(sounds);sounds.setup(fixture)
	music=BellMusic.new();fixture.add_child(music);music.setup(null);music.set_phase(1)
	await step(6)
	await event("bell_voice_strain","جهد القفز",2)
	await event("bell_voice_hurt","ألم الإصابة",2)
	await event("bell_impact","اصطدام الجرس بالأرض",3)
	await event("bell_fall","سقوط الجرس",3)
	await event("bell_voice_death","زفير النهاية",3)
	review.mode.text="نهاية الموسيقى الأصلية"
	music.stop_fight(true)
	await step(6.2)
	var metadata:={
		"scope":"Configured native audio review. Explicit fixture caption. No gameplay claim.",
		"engine":Engine.get_version_info().string,"viewport":[1280,720],"fps":60,
		"audio_scope":"Godot soundscape and Bell music helpers at their configured runtime gains. No replacement soundtrack.",
		"events":sounds.event_log,"music":"res://assets/audio/m24/music/bell_warden_clockwork.ogg",
		"failures":failures
	}
	FileAccess.open("res://previews/m24/audio_preview_metadata.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	sounds.stop_all();music.stop_all()
	fixture.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
