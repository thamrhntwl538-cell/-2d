extends SceneTree
var checks:=0
var fails:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:fails.append(label);print("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var actor:Node2D=load("res://scripts/minibosses/m26_archivist_sprite.gd").new();root.add_child(actor);await process_frame
 for clip in [["indexlock",22],["p2tr",57],["redpass",44],["pageflip",35],["finale",68],["slam",31]]:
  actor.set_animation(clip[0],2);var snap:Dictionary=actor.get_snapshot();actor.seek(float(clip[1])*snap.duration/(snap.frames-1));snap=actor.get_snapshot()
  var source:Image=Image.new();var frame:Dictionary=actor._frames[actor.frame_index];check(source.load_png_from_buffer(actor._reader.read_file(frame.file))==OK,"decodeoriginal "+clip[0]);source.convert(Image.FORMAT_RGBA8)
  var texture_image:Image=actor._texture.get_image();texture_image.convert(Image.FORMAT_RGBA8)
  var main_rect:Rect2=actor.get_frame_source_rect();var combined_rect:Rect2=snap.draw_frame_rect
  var region:=Rect2i(Vector2i(main_rect.position-combined_rect.position),source.get_size())
  var recovered:Image=texture_image.get_region(region)
  check(recovered.get_data()==source.get_data(),"GPUtextureoriginalRGBAunchanged "+clip[0])
  check(frame.has("extra_file"),"restoredoutsidecontentpresent "+clip[0])
  check(combined_rect.size.x>=main_rect.size.x and combined_rect.size.y>=main_rect.size.y,"mergedrectcontainsoriginal "+clip[0])
 actor.queue_free();await process_frame
 var report={"checks":checks,"failures":fails,"pass":fails.is_empty()}
 FileAccess.open("user://m26_imported_pixels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if fails.is_empty() else 1)
