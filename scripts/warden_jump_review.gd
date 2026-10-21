extends Node2D
# LAST LECTURE M10: dedicated jump/fall/landing playtest without enemies or cinematic gates.
# This scene uses the SAME player.gd as the actual stage, not a mock sprite-only animation.
var gameplay_active: bool = true
var hero: LastLecturePlayer
var stage_floor: float = 570.0
var status_label: Label

func _ready() -> void:
    _bind_inputs()
    var background := ColorRect.new()
    background.color = Color("172432")
    background.size = Vector2(1280, 720)
    add_child(background)
    var distance := ColorRect.new()
    distance.position = Vector2(0, 290)
    distance.size = Vector2(1280, 280)
    distance.color = Color("202d3d")
    add_child(distance)
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(640, stage_floor + 12)
    floor_body.collision_layer = 1
    floor_body.collision_mask = 2
    var floor_col := CollisionShape2D.new()
    var floor_rect := RectangleShape2D.new()
    floor_rect.size = Vector2(1280, 24)
    floor_col.shape = floor_rect
    floor_body.add_child(floor_col)
    add_child(floor_body)
    var floor_art := ColorRect.new()
    floor_art.position = Vector2(0, stage_floor)
    floor_art.size = Vector2(1280, 20)
    floor_art.color = Color("465d69")
    add_child(floor_art)
    var line := ColorRect.new()
    line.position = Vector2(0, stage_floor)
    line.size = Vector2(1280, 2)
    line.color = Color("9ddbe0")
    add_child(line)
    hero = LastLecturePlayer.new()
    hero.world_ref = self
    add_child(hero)
    hero.position = Vector2(640, stage_floor)
    var heading := Label.new()
    heading.position = Vector2(28, 28)
    heading.text = "LAST LECTURE  |  THE LANTERN WARDEN  |  M10 JUMP / FALL / LANDING"
    heading.add_theme_font_size_override("font_size", 22)
    add_child(heading)
    var controls := Label.new()
    controls.position = Vector2(28, 65)
    controls.text = "A/D or LEFT/RIGHT: RUN     SPACE: JUMP     B: SWITCH BLADE OWNERSHIP     F: FLIP DIRECTION"
    controls.add_theme_font_size_override("font_size", 16)
    add_child(controls)
    status_label = Label.new()
    status_label.position = Vector2(28, 103)
    status_label.add_theme_font_size_override("font_size", 16)
    add_child(status_label)
    var note := Label.new()
    note.position = Vector2(28, 649)
    note.text = "Test: Idle -> Jump -> Apex -> Fall -> Landing -> Idle, then Run -> Jump -> Landing -> Run."
    add_child(note)

func _bind_inputs() -> void:
    var keys := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_SPACE], "dash": [KEY_K], "attack": [KEY_J], "parry": [KEY_P], "spell": [KEY_L], "look_up": [KEY_W, KEY_UP], "look_down": [KEY_S, KEY_DOWN]}
    for action_name in keys:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
        for key in keys[action_name]:
            var found := false
            for old_event in InputMap.action_get_events(action_name):
                if old_event is InputEventKey and old_event.keycode == key:
                    found = true
                    break
            if not found:
                var ev := InputEventKey.new()
                ev.keycode = key
                InputMap.action_add_event(action_name, ev)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_B:
            hero.has_blade = not hero.has_blade
        elif event.keycode == KEY_F:
            hero.facing *= -1

func _process(_delta: float) -> void:
    if hero != null and status_label != null:
        status_label.text = "STATE: %s   |   BLADE: %s   |   VERTICAL SPEED: %.0f   |   GROUNDED: %s" % [hero.current_pose, "SHEATHED" if hero.has_blade else "NOT COLLECTED", hero.velocity.y, str(hero.is_on_floor())]

func play_sfx(_sound: String) -> void:
    pass
func emit_burst(_point: Vector2, _color: Color, _count: int) -> void:
    pass
func show_tip(_text: String) -> void:
    pass
func player_fell() -> void:
    hero.position = Vector2(640, stage_floor)
    hero.velocity = Vector2.ZERO
