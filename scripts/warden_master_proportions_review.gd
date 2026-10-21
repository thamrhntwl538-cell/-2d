extends Node2D
# Pure visualization of current M10 assets, NOT a replacement animation or physics controller.
# The same display scale and frame anchoring are applied to all three compared poses.
const MASTER_SOURCE_SIZE: Vector2 = Vector2(512, 512)
const MASTER_FRAME_CENTER: Vector2 = Vector2(256, 256)
const MASTER_FOOT_Y: float = 456.0
const GAMEPLAY_ART_SCALE: float = 0.40
const REVIEW_SCALE: float = 0.78
const IDLE_PATH: String = "res://assets/warden_m09_whole_body/unarmed_idle.png"
const RUN_PATH: String = "res://assets/warden_run_m02/run_%02d.png"
const JUMP_PATH: String = "res://assets/warden_jump_m10/jump_%02d.png"
var run_index: int = 3
var jump_index: int = 3
var cards: Array[Sprite2D] = []
var note_label: Label

func _ready() -> void:
    var background := ColorRect.new()
    background.color = Color("17212d")
    background.size = Vector2(1280, 720)
    add_child(background)
    var heading := Label.new()
    heading.text = "LAST LECTURE | WARDEN MASTER PROPORTIONS | M11"
    heading.position = Vector2(32, 25)
    heading.add_theme_font_size_override("font_size", 25)
    add_child(heading)
    for i in range(3):
        var holder := Node2D.new()
        holder.position = Vector2(245.0 + float(i) * 390.0, 540.0)
        add_child(holder)
        var sprite := Sprite2D.new()
        sprite.centered = true
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        sprite.scale = Vector2.ONE * REVIEW_SCALE
        sprite.position = Vector2(0.0, (MASTER_FRAME_CENTER.y - MASTER_FOOT_Y) * REVIEW_SCALE)
        holder.add_child(sprite)
        cards.append(sprite)
        var label_node := Label.new()
        label_node.position = Vector2(-125, 65)
        label_node.text = ["IDLE", "RUN", "JUMP / AIRBORNE"][i]
        label_node.add_theme_font_size_override("font_size", 22)
        holder.add_child(label_node)
    note_label = Label.new()
    note_label.position = Vector2(32, 640)
    note_label.text = "LEFT/RIGHT change RUN frame | SPACE changes JUMP pose | canvas 512x512 | same art scale"
    add_child(note_label)
    var warning := Label.new()
    warning.position = Vector2(32, 676)
    warning.text = "IMPORTANT: bent legs/cape alter silhouette; artwork anatomy still requires review."
    add_child(warning)
    _show_textures()
    queue_redraw()

func _show_textures() -> void:
    var paths: Array[String] = [IDLE_PATH, RUN_PATH % run_index, JUMP_PATH % jump_index]
    for i in range(3):
        cards[i].texture = load(paths[i])

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_RIGHT:
            run_index = (run_index + 1) % 6
        elif event.keycode == KEY_LEFT:
            run_index = (run_index + 5) % 6
        elif event.keycode == KEY_SPACE:
            jump_index = (jump_index + 1) % 8
        else:
            return
        _show_textures()
        queue_redraw()

func _draw() -> void:
    for i in range(3):
        var x: float = 245.0 + float(i) * 390.0
        var y: float = 540.0
        # Shared floor pivot and approximate upright 285px target, NOT a forced sprite resize.
        draw_line(Vector2(x - 150, y), Vector2(x + 150, y), Color("80d9e2"), 2.0)
        draw_line(Vector2(x, y - 285.0 * REVIEW_SCALE), Vector2(x, y + 15), Color("819cad", 0.35), 1.0)
        draw_line(Vector2(x - 150, y - 285.0 * REVIEW_SCALE), Vector2(x + 150, y - 285.0 * REVIEW_SCALE), Color("b7c6d4", 0.3), 1.0)
        draw_circle(Vector2(x, y), 4.0, Color("e9dfc5"))
