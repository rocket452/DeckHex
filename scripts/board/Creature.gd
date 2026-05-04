extends Control
class_name Creature

signal died(creature: Creature)

const HERO_SPRITE_FRAMES_PATH := "res://assets/duelyst/f1_general.tres"
const HERO_IDLE_ANIMATION := "idle"
const HERO_MOVE_ANIMATION := "run"
const HERO_ATTACK_ANIMATION := "attack"
const HERO_DEATH_ANIMATION := "death"
const HERO_HIT_ANIMATION := "hit"
const ARCHER_SPRITE_FRAMES_PATH := "res://assets/duelyst/neutral_mercranged1.tres"
const ARCHER_IDLE_ANIMATION := "idle"
const ARCHER_MOVE_ANIMATION := "run"
const ARCHER_ATTACK_ANIMATION := "attack"
const ARCHER_DEATH_ANIMATION := "death"
const ARCHER_HIT_ANIMATION := "hit"
const ZOMBIE_SPRITE_FRAMES_PATH := "res://assets/duelyst/f4_abyssiansentinel.tres"
const ZOMBIE_IDLE_ANIMATION := "idle"
const ZOMBIE_MOVE_ANIMATION := "run"
const ZOMBIE_ATTACK_ANIMATION := "attack"
const ZOMBIE_DEATH_ANIMATION := "death"
const ZOMBIE_HIT_ANIMATION := "hit"
const HERO_BASE_OFFSET := Vector2(-8.5, 15.0)
const ARCHER_BASE_OFFSET := Vector2(-1.5, 5.0)
const ZOMBIE_BASE_OFFSET := Vector2(1.0, 30.0)
const ATTACK_DAMAGE_FRAME := 3

var card_data: CardData
var owner_id := "player"
var cell := Vector2i.ZERO
var attack := 0
var max_health := 0
var current_health := 0
var movement := 0
var attack_range := 1
var summoned_turn := 0
var moved_this_turn := false
var attacked_this_turn := false
var is_hero := false
var is_dying := false
var unit_sprite_frames: SpriteFrames
var unit_animation_ticket := 0

@onready var label: RichTextLabel = $Label
@onready var hero_sprite: AnimatedSprite2D = $HeroSprite


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(136, 136)
	size = custom_minimum_size
	resized.connect(_layout_hero_visual)
	_configure_hero_sprite()
	_layout_hero_visual()
	_refresh_label()


func setup(data: CardData, owner: String, start_cell: Vector2i, current_turn: int, hero_unit := false) -> void:
	card_data = data
	owner_id = owner
	cell = start_cell
	is_hero = hero_unit
	attack = data.attack
	max_health = data.health
	current_health = data.health
	movement = data.movement
	attack_range = data.attack_range
	is_dying = false
	label.visible = true
	if is_hero:
		custom_minimum_size = Vector2(288, 288)
		size = custom_minimum_size
	elif _uses_animated_sprite():
		custom_minimum_size = Vector2(136, 136)
		size = custom_minimum_size
	summoned_turn = current_turn
	moved_this_turn = false
	attacked_this_turn = false
	name = "%s_%s" % [owner_id.capitalize(), data.display_name.replace(" ", "")]
	_configure_hero_sprite()
	_layout_hero_visual()
	_refresh_label()
	queue_redraw()


func begin_turn() -> void:
	if is_dying:
		return
	moved_this_turn = false
	attacked_this_turn = false
	play_unit_idle()
	_refresh_label()


func is_summoning_sick(current_turn: int) -> bool:
	if is_hero:
		return false
	return current_turn <= summoned_turn


func can_move(current_turn: int) -> bool:
	return not is_dying and not is_summoning_sick(current_turn) and not moved_this_turn and movement > 0


func can_attack(current_turn: int) -> bool:
	return not is_dying and not is_summoning_sick(current_turn) and not attacked_this_turn and attack > 0


func mark_moved() -> void:
	if is_dying:
		return
	moved_this_turn = true
	play_unit_action(_get_move_animation_name(), _get_action_duration("move"))
	_refresh_label()


func mark_attacked() -> void:
	if is_dying:
		return
	attacked_this_turn = true
	play_unit_action(_get_attack_animation_name(), _get_action_duration("attack"))
	_refresh_label()


func take_damage(amount: int) -> void:
	if is_dying:
		return
	current_health = max(0, current_health - amount)
	_refresh_label()
	if current_health <= 0:
		is_dying = true
		label.visible = false
		queue_redraw()
		died.emit(self)
	else:
		_play_damage_feedback()


func _refresh_label() -> void:
	if not is_inside_tree() or card_data == null:
		return
	var initial := card_data.display_name.substr(0, 1).to_upper()
	var exhausted := ""
	if moved_this_turn or attacked_this_turn:
		exhausted = "*"
	var health_color := "#FAF5DC" if current_health >= max_health else "#FF4444"
	if is_hero or _is_zombie():
		label.text = "[center]%d/[color=%s]%d[/color]%s[/center]" % [attack, health_color, current_health, exhausted]
	else:
		label.text = "[center]%s%s\n%d/[color=%s]%d[/color][/center]" % [initial, exhausted, attack, health_color, current_health]
	label.add_theme_font_size_override("normal_font_size", 16)


func _configure_hero_sprite() -> void:
	if not is_inside_tree():
		return
	if _uses_animated_sprite():
		if unit_sprite_frames == null:
			unit_sprite_frames = load(_get_sprite_frames_path()) as SpriteFrames
		if unit_sprite_frames == null:
			hero_sprite.sprite_frames = null
			hero_sprite.visible = false
			return
		hero_sprite.sprite_frames = unit_sprite_frames
		hero_sprite.visible = true
		play_unit_idle()
	else:
		hero_sprite.sprite_frames = null
		hero_sprite.visible = false

func _layout_hero_visual() -> void:
	if not is_inside_tree():
		return
	hero_sprite.flip_h = _is_zombie()
	if is_hero:
		hero_sprite.scale = Vector2(2.56, 2.56)
		hero_sprite.position = _sprite_position_for_base(HERO_BASE_OFFSET)
		label.offset_top = -50.0
	elif _is_archer():
		hero_sprite.scale = Vector2(2.56, 2.56)
		hero_sprite.position = _sprite_position_for_base(ARCHER_BASE_OFFSET)
		label.offset_top = -40.0
	elif _is_zombie():
		hero_sprite.scale = Vector2(2.56, 2.56)
		hero_sprite.position = _sprite_position_for_base(ZOMBIE_BASE_OFFSET)
		label.offset_top = -40.0
	else:
		hero_sprite.position = Vector2(size.x * 0.5, size.y * 0.5)
		hero_sprite.scale = Vector2.ONE
		label.offset_top = -30.0


func _sprite_position_for_base(base_offset: Vector2) -> Vector2:
	var offset := base_offset
	if hero_sprite.flip_h:
		offset.x = -offset.x
	return size * 0.5 - offset * hero_sprite.scale


func play_unit_idle() -> void:
	if is_dying or not _uses_animated_sprite() or hero_sprite.sprite_frames == null:
		return
	var animation_name := _get_idle_animation_name()
	if not hero_sprite.sprite_frames.has_animation(animation_name):
		return
	if hero_sprite.animation != animation_name or not hero_sprite.is_playing():
		hero_sprite.play(animation_name)


func play_unit_action(animation_name: String, duration: float) -> void:
	if is_dying or not _uses_animated_sprite() or hero_sprite.sprite_frames == null:
		return
	if not hero_sprite.sprite_frames.has_animation(animation_name):
		play_unit_idle()
		return
	unit_animation_ticket += 1
	var current_ticket := unit_animation_ticket
	hero_sprite.play(animation_name)
	_return_to_idle_after(duration, current_ticket)


func play_unit_death() -> void:
	if not _uses_animated_sprite() or hero_sprite.sprite_frames == null:
		return
	var animation_name := _get_death_animation_name()
	if animation_name.is_empty() or not hero_sprite.sprite_frames.has_animation(animation_name):
		return
	unit_animation_ticket += 1
	hero_sprite.play(animation_name)
	var duration := _get_animation_duration(animation_name)
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout


func _play_damage_feedback() -> void:
	var animation_name := _get_hit_animation_name()
	if _uses_animated_sprite() and hero_sprite.sprite_frames != null and hero_sprite.sprite_frames.has_animation(animation_name):
		var duration := _get_animation_duration(animation_name)
		play_unit_action(animation_name, duration)
	else:
		_flash_damage()


func get_attack_hit_delay() -> float:
	if not _uses_animated_sprite() or hero_sprite.sprite_frames == null:
		return 0.0
	var animation_name := _get_attack_animation_name()
	if animation_name.is_empty() or not hero_sprite.sprite_frames.has_animation(animation_name):
		return 0.0
	return _get_animation_delay_to_frame(animation_name, ATTACK_DAMAGE_FRAME)


func _get_animation_duration(animation_name: String) -> float:
	if not _uses_animated_sprite() or hero_sprite.sprite_frames == null:
		return 0.0
	var fps := hero_sprite.sprite_frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.0
	var duration := 0.0
	for frame_index in hero_sprite.sprite_frames.get_frame_count(animation_name):
		duration += hero_sprite.sprite_frames.get_frame_duration(animation_name, frame_index) / fps
	return duration


func _get_animation_delay_to_frame(animation_name: String, frame_number: int) -> float:
	if not _uses_animated_sprite() or hero_sprite.sprite_frames == null:
		return 0.0
	var fps := hero_sprite.sprite_frames.get_animation_speed(animation_name)
	if fps <= 0.0:
		return 0.0
	var frames_before_target := clampi(frame_number - 1, 0, hero_sprite.sprite_frames.get_frame_count(animation_name))
	var duration := 0.0
	for frame_index in frames_before_target:
		duration += hero_sprite.sprite_frames.get_frame_duration(animation_name, frame_index) / fps
	return duration


func _return_to_idle_after(duration: float, ticket: int) -> void:
	await get_tree().create_timer(duration).timeout
	if ticket == unit_animation_ticket:
		play_unit_idle()


func _uses_animated_sprite() -> bool:
	return is_hero or _is_archer() or _is_zombie()


func _is_archer() -> bool:
	return card_data != null and card_data.id == "archer"


func _is_zombie() -> bool:
	return card_data != null and card_data.id == "zombie"


func _get_sprite_frames_path() -> String:
	if is_hero:
		return HERO_SPRITE_FRAMES_PATH
	if _is_archer():
		return ARCHER_SPRITE_FRAMES_PATH
	if _is_zombie():
		return ZOMBIE_SPRITE_FRAMES_PATH
	return ""


func _get_idle_animation_name() -> String:
	if is_hero:
		return HERO_IDLE_ANIMATION
	if _is_archer():
		return ARCHER_IDLE_ANIMATION
	if _is_zombie():
		return ZOMBIE_IDLE_ANIMATION
	return ""


func _get_move_animation_name() -> String:
	if is_hero:
		return HERO_MOVE_ANIMATION
	if _is_archer():
		return ARCHER_MOVE_ANIMATION
	if _is_zombie():
		return ZOMBIE_MOVE_ANIMATION
	return ""


func _get_attack_animation_name() -> String:
	if is_hero:
		return HERO_ATTACK_ANIMATION
	if _is_archer():
		return ARCHER_ATTACK_ANIMATION
	if _is_zombie():
		return ZOMBIE_ATTACK_ANIMATION
	return ""


func _get_death_animation_name() -> String:
	if is_hero:
		return HERO_DEATH_ANIMATION
	if _is_archer():
		return ARCHER_DEATH_ANIMATION
	if _is_zombie():
		return ZOMBIE_DEATH_ANIMATION
	return ""


func _get_hit_animation_name() -> String:
	if is_hero:
		return HERO_HIT_ANIMATION
	if _is_archer():
		return ARCHER_HIT_ANIMATION
	if _is_zombie():
		return ZOMBIE_HIT_ANIMATION
	return ""


func _get_action_duration(action_name: String) -> float:
	if is_hero:
		if action_name == "attack":
			return 0.75
		return 1.20
	if _is_archer():
		if action_name == "attack":
			return 0.55
		return 1.20
	if _is_zombie():
		if action_name == "attack":
			return 0.60
		return 1.20
	return 0.0


func _flash_damage() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.45, 0.36, 1), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)


func _draw() -> void:
	if card_data == null:
		return
	if _uses_animated_sprite():
		if is_dying:
			return
		var footer_height := 30.0
		var footer_margin := 8.0
		if is_hero:
			footer_height = 46.0
			footer_margin = 10.0
		draw_rect(
			Rect2(
				Vector2(footer_margin, size.y - footer_height - footer_margin),
				Vector2(size.x - footer_margin * 2.0, footer_height)
			),
			Color(0.05, 0.07, 0.10, 0.82),
			true
		)
		return

	var rect := Rect2(Vector2.ZERO, size)
	var color := card_data.accent_color
	var border := Color(0.92, 0.84, 0.58, 1)
	var border_width := 2.0
	if owner_id == "enemy":
		color = color.darkened(0.22).lerp(Color(0.65, 0.12, 0.13, 1), 0.35)
		border = Color(0.96, 0.48, 0.42, 1)
	draw_rect(rect, Color(0, 0, 0, 0.45), true)
	draw_rect(rect.grow(-3), color, true)
	draw_rect(rect.grow(-3), border, false, border_width)
