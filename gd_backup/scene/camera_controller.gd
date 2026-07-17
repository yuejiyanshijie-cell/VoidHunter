# camera_controller.gd
# Camera2D 扩展 — 平滑跟随玩家，屏幕震动
extends Camera2D

# =============================================================================
# 跟随参数
# =============================================================================
@export var follow_target: Node2D = null
@export var follow_speed: float = 8.0
@export var look_ahead: float = 80.0
@export var look_ahead_vertical: float = 20.0

# =============================================================================
# 震动参数
# =============================================================================
var shake_amplitude: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_offset: Vector2


# =============================================================================
# 生命周期
# =============================================================================
func _ready() -> void:
	original_offset = offset
	EventBus.screen_shake_request.connect(_on_screen_shake)


func _process(delta: float) -> void:
	if follow_target:
		_smooth_follow(delta)
	_update_shake(delta)


# =============================================================================
# 平滑跟随
# =============================================================================
func _smooth_follow(delta: float) -> void:
	var target_pos = follow_target.global_position

	# 前瞻偏移（基于玩家朝向和速度）
	var look_offset := Vector2.ZERO
	var facing: float = 1.0
	var vel_y: float = 0.0

	if follow_target.has_method("get"):
		pass  # not needed for now
	if follow_target.get("facing_direction") != null:
		facing = follow_target.facing_direction
	if follow_target.get("velocity") != null:
		vel_y = follow_target.velocity.y

	look_offset.x = facing * look_ahead
	if vel_y < 0:
		look_offset.y = -look_ahead_vertical
	elif vel_y > 100:
		look_offset.y = look_ahead_vertical

	target_pos += look_offset

	var weight = min(follow_speed * delta, 1.0)
	global_position = global_position.lerp(target_pos, weight)


# =============================================================================
# 震动效果
# =============================================================================
func _on_screen_shake(amplitude: float, duration: float) -> void:
	shake_amplitude = max(shake_amplitude, amplitude)
	shake_duration = max(shake_duration, duration)
	shake_timer = shake_duration


func _update_shake(delta: float) -> void:
	if shake_timer <= 0:
		offset = original_offset
		return

	shake_timer -= delta
	var t = shake_timer / max(shake_duration, 0.001)
	offset = original_offset + Vector2(
		randf_range(-shake_amplitude, shake_amplitude) * t,
		randf_range(-shake_amplitude, shake_amplitude) * t
	)
