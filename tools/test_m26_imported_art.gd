extends SceneTree
var sprite:Node2D
var failures:Array[String]=[]
var checks:=0
var events:Array[String]=[]
var ends:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures.append(label);print("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 sprite=load("res://scripts/minibosses/m26_archivist_sprite.gd").new();root.add_child(sprite)
 sprite.event_crossed.connect(func(name:String):events.append(name))
 sprite.animation_finished.connect(func():ends+=1)
 await process_frame
 check(sprite.get_available_animations(1).size()==11,"p1 has11physicalsheets")
 check(sprite.get_available_animations(2).size()==18,"p2 has18physicalsheets")
 for phase in [1,2]:
  for name in sprite.get_available_animations(phase):
   check(sprite.set_animation(name,phase),"opens p%d/%s" %[phase,name])
   check(sprite.get_snapshot().frame==0,"starts frame0 "+name)
   var snap:Dictionary=sprite.get_snapshot()
   for index in range(snap.frames):
    var time:float=float(index)*snap.duration/(snap.frames if snap.loop else snap.frames-1)
    sprite.seek(time)
    check(sprite.frame_index==index,"frame mapping p%d/%s/%d" %[phase,name,index])
   check(sprite.get_snapshot().cache_frames<=8,"boundedtexturecache "+name)
 check(not sprite.set_animation("missing"),"unknownanimationrejected")
 sprite.set_animation("combo5",1);check(sprite.resolved_source_phase==2,"phase1p2onlyfallbackexplicit")
 sprite.set_animation("walk",1);events.clear();sprite.advance(1.8)
 check(events.count("footstep_R")==2 and events.count("footstep_L")==2,"large-delta2walkcycles events exactlyonce")
 sprite.seek(.1);events.clear();sprite.seek(.8);check(events.is_empty(),"seekneverplayssounds")
 sprite.set_playing(false);var paused:float=sprite.animation_time;sprite.advance(.5);check(sprite.animation_time==paused,"pausefreezesclock")
 sprite.set_playing(true);sprite.playback_speed=2; sprite.set_animation("slam",1);sprite.advance(.475);check(is_equal_approx(sprite.animation_time,.95),"singlespeedauthority")
 sprite.seek(.95);check(sprite.get_active_hitboxes().size()>0,"slamactivehitboxes")
 sprite.position=Vector2(900,600);sprite.visual_scale=.5;sprite.set_facing(1)
 var raw:Rect2=sprite.get_active_hitboxes()[0].rect;var right:Rect2=sprite.get_hitboxes_world()[0].rect
 check(right.position.is_equal_approx(sprite.position+raw.position*.5),"rightboxscalesonce")
 sprite.set_facing(-1);var left:Rect2=sprite.get_hitboxes_world()[0].rect
 check(is_equal_approx(left.position.x,900-raw.end.x*.5),"leftboxmirrorsaboutfootpivot")
 sprite.playback_speed=1;sprite.set_animation("death",1);ends=0;sprite.advance(4.0);sprite.advance(4.0)
 check(ends==1 and sprite.frame_index==71,"oneshotendsandholdsexactlastframe")
 sprite.queue_free();await process_frame
 var report={"checks":checks,"failures":failures,"pass":failures.is_empty()}
 FileAccess.open("user://m26_imported_art.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
