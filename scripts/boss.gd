extends StaticBody3D
class_name RitualBriarBoss

signal state_changed(state_name: String)
signal health_changed(current: float, maximum: float)
signal attack_ready(phase: int, target_position: Vector3)

enum State { INTRO, IDLE, SELECT_ATTACK, TELEGRAPH, ATTACK, RECOVERY, STAGGER, PHASE_TRANSITION, DEATH }
const ATLAS_PATH := "res://assets/boss/ritual_briar_atlas_v2.png"
const ACTION_ATLAS_PATH := "res://assets/boss/ritual_briar_actions.png"
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 3

@export var max_health := 100.0
@export var intro_duration := 1.4
@export var idle_duration := 1.1
@export var telegraph_duration := 0.76
@export var attack_duration := 0.28
@export var recovery_duration := 0.7
@export var stagger_duration := 0.34

@onready var sprite: AnimatedSprite3D = $Visual/BossSprite
@onready var contact_shadow: MeshInstance3D = $ContactShadow

var health := 100.0
var phase := 1
var state: State = State.INTRO
var state_timer := 0.0
var _frames := SpriteFrames.new()
var _arena: Node
var pending_skill := 0


func _ready() -> void:
	health = max_health
	_arena = get_parent()
	_build_frames()
	_setup_contact_shadow()
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
		_play_visual("collapse")
		return
	if phase == 1 and health <= max_health * 0.5:
		phase = 2
		_enter(State.PHASE_TRANSITION, 1.0)
		_play_visual("telegraph")
		return
	_enter(State.STAGGER, stagger_duration)
	_play_visual("stagger")


func _enter(next_state: State, duration: float) -> void:
	state = next_state
	state_timer = duration
	state_changed.emit(State.keys()[state])
	if state == State.IDLE:
		_play_visual("idle")
	elif state == State.TELEGRAPH:
		_play_visual("telegraph")
	elif state == State.ATTACK:
		_play_visual(["attack_slam", "attack_sweep", "attack_barrage"][clampi(pending_skill,0,2)])
	elif state == State.RECOVERY:
		_play_visual("idle")
	elif state == State.STAGGER:
		_play_visual("stagger")


func _build_frames() -> void:
	var texture := load(ATLAS_PATH) as Texture2D
	var action_texture := load(ACTION_ATLAS_PATH) as Texture2D
	_add_row_animation(texture, "idle", 0, 4.0, true)
	_add_row_animation(texture, "telegraph", 1, 8.0, false)
	_add_row_animation(texture, "stagger", 2, 12.0, false)
	_add_row_animation(texture, "collapse", 2, 5.0, false)
	_add_action_sequence(action_texture,"attack_sweep",0,[0,1,2,3],13.0)
	_add_action_sequence(action_texture,"attack_slam",1,[0,1,2,3],14.0)
	_add_action_sequence(action_texture,"attack_barrage",1,[0,1,2,3,2,1,0,3],18.0)
	if _frames.get_frame_count("collapse") > 0:
		_frames.set_animation_loop("collapse", false)
		_frames.set_frame("collapse", 3, _frames.get_frame_texture("stagger", 3))


func _add_row_animation(texture: Texture2D, name: String, row: int, speed: float, looped: bool) -> void:
	_frames.add_animation(name)
	_frames.set_animation_speed(name, speed)
	_frames.set_animation_loop(name, looped)
	for col in range(4):
		_frames.add_frame(name, _atlas_frame(texture,col,row))


func _add_action_sequence(texture: Texture2D, name: String, row: int, columns: Array[int], speed: float) -> void:
	_frames.add_animation(name)
	_frames.set_animation_speed(name,speed)
	_frames.set_animation_loop(name,false)
	for col in columns:
		_frames.add_frame(name,_atlas_frame(texture,col,row,4,2))


func _atlas_frame(texture: Texture2D, col: int, row: int, columns: int = ATLAS_COLUMNS, rows: int = ATLAS_ROWS) -> AtlasTexture:
	var cell_width := texture.get_width() / float(columns)
	var cell_height := texture.get_height() / float(rows)
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(col * cell_width,row * cell_height,cell_width,cell_height)
	return frame


func _play_visual(animation_name: String) -> void:
	if not _frames.has_animation(animation_name): return
	var texture := load(ACTION_ATLAS_PATH) as Texture2D if animation_name.begins_with("attack_") else load(ATLAS_PATH) as Texture2D
	var columns := 4.0
	sprite.offset = Vector2(-(texture.get_width() / columns) * 0.5,0.0)
	sprite.play(animation_name)


func _setup_contact_shadow() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.38
	mesh.height = 0.045
	contact_shadow.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.018,0.012,0.014,0.62)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	contact_shadow.material_override = material
