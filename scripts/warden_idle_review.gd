extends Node2D
# Milestone 01: Fixed height, face-direction, single-pose idle.
# F6 this scene in Godot 4.7. No dependency on main game's scripts or input map.
const PIVOT_Y: float = 456.0
const LOOKS = ["SMALL · 100 px", "TARGET · 126 px", "LARGE · 145 px"]
const SCALE_LEVELS = [0.32, 0.40, 0.46]
var selected_size: int = 1
var facing_right: bool = true
var weapon_acquired: bool = false
var actor: Sprite2D
var title: Label
var hint: Label
var scene_floor: float = 586.0
var sprite_unarmed: Texture2D = preload("res://assets/warden_m09_whole_body/unarmed_idle.png")
var sprite_sheathed: Texture2D = preload("res://assets/warden_m09_whole_body/sheathed_idle.png")

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color("141c28")
    bg.size = Vector2(1280, 720)
    add_child(bg)
    var horizon := ColorRect.new()
    horizon.color = Color("1e2a37")
    horizon.position = Vector2(0, scene_floor)
    horizon.size = Vector2(1280, 134)
    add_child(horizon)
    var baseline := Line2D.new()
    baseline.points = PackedVector2Array([Vector2(0, scene_floor), Vector2(1280,scene_floor)])
    baseline.width = 2.0
    baseline.default_color = Color("8cbcc8")
    add_child(baseline)
    var muted := Label.new()
    muted.position = Vector2(44, 24)
    muted.text = "LAST LECTURE  /  LANTERN WARDEN  /  MILESTONE 09 / APPROVED FULL-BODY IDLE"
    muted.add_theme_font_size_override("font_size", 23)
    add_child(muted)
    title = Label.new()
    title.position = Vector2(44, 75)
    title.add_theme_font_size_override("font_size", 19)
    add_child(title)
    hint = Label.new()
    hint.position = Vector2(44, 648)
    hint.add_theme_font_size_override("font_size", 17)
    hint.text = "1 / 2 / 3: size   |   F: flip facing   |   B: blade collected   |   R: reset"
    add_child(hint)
    actor = Sprite2D.new()
    actor.name = "LanternWarden_Idle_NoSway"
    actor.centered = true
    actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    add_child(actor)
    _refresh()

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    if not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_1: selected_size = 0
        KEY_2: selected_size = 1
        KEY_3: selected_size = 2
        KEY_F: facing_right = not facing_right
        KEY_B: weapon_acquired = not weapon_acquired
        KEY_R:
            selected_size = 1
            facing_right = true
            weapon_acquired = false
    _refresh()

func _refresh() -> void:
    var sz: float = SCALE_LEVELS[selected_size]
    actor.texture = sprite_sheathed if weapon_acquired else sprite_unarmed
    actor.flip_h = not facing_right
    actor.scale = Vector2.ONE * sz
    actor.position = Vector2(640.0, scene_floor + (256.0-PIVOT_Y)*sz)
    actor.modulate = Color.WHITE
    title.text = "SIZE: %s   |   SIDE: %s   |   SWORD: %s   |   1 UNIQUE FRAME / 0 JITTER" % [LOOKS[selected_size], "RIGHT" if facing_right else "LEFT", "SHEATHED" if weapon_acquired else "NOT ACQUIRED"]
