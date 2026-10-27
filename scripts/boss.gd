extends StaticBody3D
class_name RitualBriarBoss

signal state_changed(state_name: String)
signal health_changed(current: float, maximum: float)
signal attack_ready(phase: int, target_position: Vector3)

enum State { INTRO, IDLE, SELECT_ATTACK, TELEGRAPH, ATTACK, RECOVERY, STAGGER, PHASE_TRANSITION, DEATH }
const ATLAS_PATH := "res://assets/boss/ritual_briar_atlas.png"
const CELL := 512

@export var max_health := 100.0
@export var intro_duration := 1.4
@export var idle_duration := 1.1
@export var telegraph_duration := 0.95
@export var attack_duration := 0.28
@export var recovery_duration := 0.7
@export var stagger_duration := 0.34

@onready var sprite: AnimatedSprite3D = $Visual/BossSprite

var health := 100.0
var phase := 1
var state: State = State.INTRO
var state_timer := 0.0
var _frames := SpriteFrames.new()
var _arena: Node


func _ready() -> void:
	health = max_health
	_arena = get_parent()
	_build_frames()
	sprite.sprite_frames = _frames
	sprite.play("idle")
	_enter(State.INTRO, intro_duration)


func _physics_process(delta: float) -> void:
	if state == State.DEATH:
		return
	state_timer = maxf(0.0, state_timer - delta)
	if state_timer > 0.0:
		return
	match state:
		State.INTRO, State.RECOVERY, State.STAGGER:
			_enter(State.IDLE, idle_duration)
		State.IDLE:
			_enter(State.SELECT_ATTACK, 0.12)
		State.SELECT_ATTACK:
			_enter(State.TELEGRAPH, telegraph_duration)
			var player := get_tree().get_first_node_in_group("player") as Node3D
			attack_ready.emit(phase, player.global_position if player != null else global_position)
		State.TELEGRAPH:
			_enter(State.ATTACK, attack_duration)
		State.ATTACK:
			_enter(State.RECOVERY, recovery_duration)
		State.PHASE_TRANSITION:
			_enter(State.IDLE, idle_duration * 0.8)


func receive_hit(damage: float, _knockback: Vector3, _hit_position: Vector3) -> void:
	if state == State.DEATH or state == State.PHASE_TRANSITION:
		return
	health = maxf(0.0, health - damage)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_enter(State.DEATH, 99.0)
		sprite.play("collapse")
		return
	if phase == 1 and health <= max_health * 0.5:
		phase = 2
		_enter(State.PHASE_TRANSITION, 1.0)
		sprite.play("telegraph")
		return
	_enter(State.STAGGER, stagger_duration)
	sprite.play("stagger")


func _enter(next_state: State, duration: float) -> void:
	state = next_state
	state_timer = duration
	state_changed.emit(State.keys()[state])
	if state == State.IDLE:
		sprite.play("idle")
	elif state == State.TELEGRAPH:
		sprite.play("telegraph")


func _build_frames() -> void:
	var texture := load(ATLAS_PATH) as Texture2D
	_add_row_animation(texture, "idle", 0, 4.0, true)
	_add_row_animation(texture, "telegraph", 1, 8.0, false)
	_add_row_animation(texture, "stagger", 2, 12.0, false)
	_add_row_animation(texture, "collapse", 2, 5.0, false)
	if _frames.get_frame_count("collapse") > 0:
		_frames.set_animation_loop("collapse", false)
		_frames.set_frame("collapse", 3, _frames.get_frame_texture("stagger", 3))


func _add_row_animation(texture: Texture2D, name: String, row: int, speed: float, looped: bool) -> void:
	_frames.add_animation(name)
	_frames.set_animation_speed(name, speed)
	_frames.set_animation_loop(name, looped)
	for col in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(col * CELL, row * CELL, CELL, CELL)
		_frames.add_frame(name, frame)
