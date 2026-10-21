extends Node2D
# M02 dedicated reproducible preview: same high-detail idle and run textures as gameplay.
const FOOT_Y: float = 456.0
const SCALE_STEPS = [0.32, 0.40, 0.46]
var size_level: int = 1
var sword_obtained: bool = false
var facing: int = 1
var is_paused: bool = false
var running: bool = false
var stop_remaining: float = 0.0
var speed: float = 13.0
var player: AnimatedSprite2D
var info: Label
var floor_y: float = 580.0

func _ready() -> void:
    var background := ColorRect.new()
    background.color = Color("141c28")
    background.size = Vector2(1280,720)
    add_child(background)
    var back_rail := ColorRect.new()
    back_rail.color = Color("192939")
    back_rail.position = Vector2(0.0,330.0)
    back_rail.size = Vector2(1280,249)
    add_child(back_rail)
    var ground := ColorRect.new()
    ground.color = Color("283747")
    ground.position = Vector2(0.0,floor_y)
    ground.size = Vector2(1280,140)
    add_child(ground)
    var guide := Line2D.new()
    guide.points = PackedVector2Array([Vector2(0,floor_y), Vector2(1280,floor_y)])
    guide.width = 2.0
    guide.default_color = Color("9bd5da")
    add_child(guide)
    var header := Label.new()
    header.position = Vector2(48,30)
    header.text = "LAST LECTURE   |   THE LANTERN WARDEN   |   M09 INTACT APPROVED IDLE / APPROVED RUN + STOP"
    header.add_theme_font_size_override("font_size",23)
    add_child(header)
    info = Label.new()
    info.position = Vector2(48,74)
    info.add_theme_font_size_override("font_size",18)
    add_child(info)
    var controls := Label.new()
    controls.position = Vector2(46,662)
    controls.text = "LEFT/RIGHT = RUN   |   F = FLIP   |   B = BLADE ACQUIRED   |   1/2/3 = SIZE   |   SPACE = FREEZE"
    controls.add_theme_font_size_override("font_size",17)
    add_child(controls)
    player = AnimatedSprite2D.new()
    player.name = "LanternWarden_M02_ApprovedArt"
    player.centered = true
    player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var frames := SpriteFrames.new()
    for pose_name in ["unarmed_idle", "armed_idle", "unarmed_run", "armed_run", "unarmed_stop", "armed_stop"]:
        frames.add_animation(pose_name)
        frames.set_animation_speed(pose_name, 13.0 if pose_name.ends_with("run") else (18.0 if pose_name.ends_with("stop") else 1.0))
        frames.set_animation_loop(pose_name, not pose_name.ends_with("stop"))
        if pose_name.ends_with("idle"):
            var idle_path: String = "res://assets/warden_m09_whole_body/%s.png" % ("sheathed_idle" if pose_name == "armed_idle" else "unarmed_idle")
            frames.add_frame(pose_name, load(idle_path))
        elif pose_name.ends_with("stop"):
            for i in range(2):
                frames.add_frame(pose_name, load("res://assets/warden_m09_whole_body/stop_%02d.png" % i))
        else:
            for i in range(6):
                var run_path: String = "res://assets/warden_run_m02/run_%02d.png" % i
                frames.add_frame(pose_name, load(run_path))
    player.sprite_frames = frames
    add_child(player)
    _update_visual(true)

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_1: size_level = 0
        KEY_2: size_level = 1
        KEY_3: size_level = 2
        KEY_B: sword_obtained = not sword_obtained
        KEY_F: facing *= -1
        KEY_SPACE: is_paused = not is_paused
    _update_visual(false)

func _process(delta: float) -> void:
    var direction: float = Input.get_axis("ui_left","ui_right")
    if absf(direction) > 0.05:
        facing = 1 if direction > 0.0 else -1
    var new_running: bool = absf(direction) > 0.05
    if running and not new_running:
        stop_remaining = 0.11
    elif new_running:
        stop_remaining = 0.0
    running = new_running
    stop_remaining = maxf(0.0, stop_remaining - delta)
    _update_visual(false)

func _update_visual(force_play: bool) -> void:
    if player == null:
        return
    var state: String = "run" if running else ("stop" if stop_remaining > 0.0 else "idle")
    var pose: String = ("armed_" if sword_obtained else "unarmed_") + state
    if player.animation != pose or force_play:
        player.play(pose)
    if is_paused:
        player.pause()
    elif not player.is_playing():
        player.play()
    player.flip_h = facing < 0
    var s: float = SCALE_STEPS[size_level]
    player.scale = Vector2.ONE * s
    player.position = Vector2(640.0, floor_y + (256.0-FOOT_Y)*s)
    info.text = "STATE: %s    |    HEIGHT: %d px    |    FACE: %s    |    BLADE: %s    |    FPS: 13 (same run frames before/after blade)" % [pose, int(312.0*s),"RIGHT" if facing > 0 else "LEFT", "SHEATHED" if sword_obtained else "NOT YET"]
