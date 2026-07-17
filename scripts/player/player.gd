# player.gd - Void Hunter 玩家控制器
# 状态机驱动的2D平台角色
extends CharacterBody2D

# =============================================================================
# 导出变量
# =============================================================================
@export var speed: float = 220.0
@export var jump_velocity: float = -440.0
@export var double_jump_velocity: float = -360.0

# =============================================================================
# 状态
# =============================================================================
enum PlayerState { IDLE, RUNNING, JUMPING, FALLING, DASHING, WALL_SLIDING, ATTACKING, DODGING, STUNNED, DEAD }
var current_state: PlayerState = PlayerState.IDLE

# 移动
var input_direction: float = 0.0
var facing_direction: float = 1.0
var has_double_jump: bool = true
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_timer: float = 0.0

# 战斗
var is_attacking: bool = false
var attack_combo: int = 0
var can_attack: bool = true
var is_dodging: bool = false
var dodge_cooldown_timer: float = 0.0
var is_parrying: bool = false
var parry_window: float = 0.0
const PARRY_STUN_DURATION: float = 1.5
const PARRY_WINDOW_TIME: float = 0.1
var invincibility_time: float = GameConstants.PLAYER_DASH_DURATION * 1.1
var _inv_timer: float = 0.0

# 子节点引用
@onready var wall_detector: RayCast2D = $WallDetector
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox

# 占位视觉
var _body: ColorRect
var _sword: ColorRect
var _eye: ColorRect
var _slash_fx: ColorRect   # 斩击特效层
var _trail_container: Node2D
var _orb_count: int = 0

# =============================================================================
# 攻击参数
# =============================================================================
const COMBO_WINDOW: float = 0.55
const ATTACK1_TIME: float = 0.2
const ATTACK2_TIME: float = 0.24
const ATTACK3_TIME: float = 0.32
const HEAVY_CHARGE_MIN: float = 0.35   # 长按阈值
const HEAVY_WINDUP: float = 0.15       # 重攻击前摇
const HEAVY_ACTIVE: float = 0.15       # 重攻击判定帧
const HEAVY_RECOVERY: float = 0.2      # 后摇
const DOWNSTRIKE_TIME: float = 0.25

var attack_timer: float = 0.0
var combo_window_timer: float = 0.0
var current_atk_dmg: float = 0.0
var attack_hit_list: Array[Node2D] = []
var buffer_combo: bool = false

# 重攻击蓄力
var hold_timer: float = 0.0
var is_holding: bool = false
var is_heavy_stage: int = 0  # 0=无, 1=蓄力中, 2=前摇, 3=判定, 4=后摇
var heavy_hit_done: bool = false

# 冲刺攻击
const DASH_ATTACK_BONUS: float = 1.6
var has_dash_attacked: bool = false

# 击退参数（随连击递增）
const KNOCKBACK_BASE: float = 120.0
const KNOCKBACK_PER_COMBO: float = 80.0


# =============================================================================
# 生命周期
# =============================================================================
func _ready() -> void:
	_create_visual()
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.player_died.connect(_on_died)
	
	# 检测收集品和死亡区域
	hurtbox.area_entered.connect(_on_area_entered)
	hurtbox.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if current_state == PlayerState.DEAD:
		return
	_update_timers(delta)
	_update_attack(delta)
	_update_visuals(delta)


func _physics_process(delta: float) -> void:
	if current_state == PlayerState.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_handle_input()
	_handle_gravity(delta)
	_handle_movement()
	move_and_slide()
	_update_state()
	_check_ground_state()


# =============================================================================
# 占位视觉
# =============================================================================
func _create_visual() -> void:
	_trail_container = Node2D.new()
	_trail_container.name = "Trails"
	add_child(_trail_container)

	_body = ColorRect.new()
	_body.size = Vector2(16, 28)
	_body.position = Vector2(-8, -30)
	_body.color = Color(0.06, 0.05, 0.1)
	add_child(_body)

	var head := ColorRect.new()
	head.size = Vector2(10, 6)
	head.position = Vector2(-5, -36)
	head.color = Color(0.1, 0.1, 0.16)
	_body.add_child(head)

	_eye = ColorRect.new()
	_eye.size = Vector2(4, 2)
	_eye.position = Vector2(-2, -34)
	_eye.color = Color(0, 0.85, 1)
	_body.add_child(_eye)

	_sword = ColorRect.new()
	_sword.size = Vector2(2, 13)
	_sword.position = Vector2(8, -29)
	_sword.color = Color(0.7, 0.7, 0.85)
	add_child(_sword)

	# 斩击光效层
	_slash_fx = ColorRect.new()
	_slash_fx.visible = false
	_slash_fx.z_index = 5
	add_child(_slash_fx)


# =============================================================================
# 视觉效果
# =============================================================================
func _update_visuals(_delta: float) -> void:
	if not _body:
		return
	_body.scale.x = facing_direction
	_sword.scale.x = facing_direction

	# 冲刺紫光
	_body.modulate = Color(0.6, 0.4, 1, 0.85) if is_dashing else Color(1, 1, 1, 1)
	_sword.modulate = Color(0.85, 0.65, 1, 0.85) if is_dashing else Color(1, 1, 1, 1)

	# 闪避闪烁
	var blink: bool = fmod(Time.get_ticks_msec() * 0.001, 0.08) < 0.04
	_body.visible = not (is_dodging and blink)
	_sword.visible = not (is_dodging and blink)

	# 受伤红色
	if current_state == PlayerState.STUNNED:
		_body.color = Color(0.35, 0.03, 0.03)
	else:
		_body.color = Color(0.06, 0.05, 0.1)

	# 奔跑弹动
	_body.position.y = -30 + sin(Time.get_ticks_msec() * 0.012) * 1.2 if current_state == PlayerState.RUNNING else -30


# =============================================================================
# 计时器
# =============================================================================
func _update_timers(delta: float) -> void:
	dash_timer = move_toward(dash_timer, 0, delta)
	if dash_timer <= 0 and is_dashing:
		_end_dash()
	dash_cooldown_timer = move_toward(dash_cooldown_timer, 0, delta)
	dodge_cooldown_timer = move_toward(dodge_cooldown_timer, 0, delta)
	wall_jump_timer = move_toward(wall_jump_timer, 0, delta)
	parry_window = move_toward(parry_window, 0, delta)
	if is_parrying and parry_window <= 0:
		is_parrying = false
	if _inv_timer > 0:
		_inv_timer -= delta
		if _inv_timer <= 0 and hurtbox and not is_dodging:
			hurtbox.monitoring = true

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		if is_on_floor() or coyote_timer > 0:
			_perform_jump()
			jump_buffer_timer = 0

	if coyote_timer > 0 and not is_on_floor():
		coyote_timer -= delta
	elif is_on_floor():
		coyote_timer = GameConstants.COYOTE_TIME


# =============================================================================
# 输入
# =============================================================================
func _handle_input() -> void:
	if current_state in [PlayerState.DEAD, PlayerState.STUNNED]:
		return

	input_direction = Input.get_axis("move_left", "move_right")
	if input_direction != 0:
		facing_direction = input_direction

	# Jump
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = GameConstants.JUMP_BUFFER_TIME
		_try_jump()
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	# Dash
	if Input.is_action_just_pressed("dash") and dash_timer <= 0 and dash_cooldown_timer <= 0:
		_start_dash()

	# Dodge — 可以取消攻击后摇
	if Input.is_action_just_pressed("dodge") and dodge_cooldown_timer <= 0:
		_start_dodge()

	# 攻击输入
	if Input.is_action_just_pressed("attack"):
		_on_attack_press()
	if Input.is_action_just_released("attack"):
		_on_attack_release()

	# 技能
	if Input.is_action_just_pressed("skill1"):
		_cast_skill(1)
	if Input.is_action_just_pressed("skill2"):
		_cast_skill(2)


# =============================================================================
# 状态机
# =============================================================================
func _update_state() -> void:
	if current_state in [PlayerState.DEAD, PlayerState.DODGING, PlayerState.STUNNED]:
		return
	if is_dashing:
		current_state = PlayerState.DASHING
	elif _is_wall_sliding():
		current_state = PlayerState.WALL_SLIDING
	elif is_attacking or is_heavy_stage > 0:
		current_state = PlayerState.ATTACKING
	elif not is_on_floor():
		current_state = PlayerState.JUMPING if velocity.y < 0 else PlayerState.FALLING
	elif abs(velocity.x) > 10:
		current_state = PlayerState.RUNNING
	else:
		current_state = PlayerState.IDLE


# =============================================================================
# 物理
# =============================================================================
func _handle_gravity(delta: float) -> void:
	if is_dashing:
		return
	if _is_wall_sliding():
		velocity.y = min(velocity.y + GameConstants.GRAVITY * 0.3 * delta, GameConstants.PLAYER_WALL_SLIDE_SPEED)
	else:
		velocity.y = min(velocity.y + GameConstants.GRAVITY * delta, GameConstants.TERMINAL_VELOCITY)


func _handle_movement() -> void:
	if is_dashing:
		velocity.x = facing_direction * GameConstants.PLAYER_DASH_SPEED
	elif _is_wall_sliding():
		velocity.x = input_direction * speed * 0.3
	elif is_attacking:
		velocity.x = input_direction * speed * 0.5  # 攻击中可微调站位
	else:
		velocity.x = input_direction * speed


func _check_ground_state() -> void:
	if is_on_floor():
		has_double_jump = true
		coyote_timer = GameConstants.COYOTE_TIME


func _is_wall_sliding() -> bool:
	if is_on_floor() or wall_jump_timer > 0 or input_direction == 0:
		return false
	return is_on_wall() and wall_detector and wall_detector.is_colliding()


# =============================================================================
# 跳跃
# =============================================================================
func _try_jump() -> void:
	if _is_wall_sliding():
		_perform_wall_jump()
	elif is_on_floor() or coyote_timer > 0:
		_perform_jump()
		coyote_timer = 0
	elif not is_on_floor() and has_double_jump:
		_perform_double_jump()

func _perform_jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0

func _perform_double_jump() -> void:
	velocity.y = double_jump_velocity
	has_double_jump = false
	_spawn_jump_fx()

func _perform_wall_jump() -> void:
	velocity.x = -facing_direction * GameConstants.PLAYER_WALL_JUMP_H
	velocity.y = GameConstants.PLAYER_WALL_JUMP_V
	wall_jump_timer = 0.2
	_spawn_jump_fx()

func _spawn_jump_fx() -> void:
	var ring := ColorRect.new()
	ring.size = Vector2(20, 4)
	ring.position = global_position + Vector2(-10, 10)
	ring.color = Color(0.3, 0.5, 1, 0.6)
	get_parent().add_child(ring)
	var t := create_tween()
	t.tween_property(ring, "size", Vector2(40, 1), 0.25)
	t.parallel().tween_property(ring, "color:a", 0.0, 0.25)
	t.tween_callback(ring.queue_free)


# =============================================================================
# 冲刺
# =============================================================================
func _start_dash() -> void:
	is_dashing = true
	dash_timer = GameConstants.PLAYER_DASH_DURATION
	dash_cooldown_timer = GameConstants.PLAYER_DASH_COOLDOWN
	_spawn_dash_trail()

func _spawn_dash_trail() -> void:
	var trail := ColorRect.new()
	trail.size = Vector2(12, 20)
	trail.position = global_position + Vector2(-facing_direction * 10, -20)
	trail.color = Color(0.4, 0.25, 1, 0.35)
	trail.scale.x = facing_direction
	get_parent().add_child(trail)
	var t := create_tween()
	t.tween_property(trail, "color:a", 0.0, 0.3)
	t.parallel().tween_property(trail, "size:x", 4, 0.3)
	t.tween_callback(trail.queue_free)

func _end_dash() -> void:
	is_dashing = false
	has_dash_attacked = false
	velocity.x = input_direction * speed

# =============================================================================
# 冲刺攻击
# =============================================================================
func _start_dash_attack() -> void:
	is_attacking = true
	can_attack = false
	has_dash_attacked = true
	attack_hit_list.clear()
	attack_timer = 0.22
	current_atk_dmg = GameConstants.ATTACK_DAMAGE_LIGHT * DASH_ATTACK_BONUS
	combo_window_timer = 0

	# 冲刺中出刀：短暂加速 + 旋转斩
	velocity.x = facing_direction * GameConstants.PLAYER_DASH_SPEED * 1.15
	_sword.color = Color(0.5, 0.35, 1)

	# 旋转斩视觉效果
	_start_dash_slash_animation()

	# 命中判定
	get_tree().create_timer(0.05).timeout.connect(_dash_attack_hit_check)

	# 回刀
	get_tree().create_timer(attack_timer).timeout.connect(func():
		is_attacking = false
		_sword.color = Color(0.7, 0.7, 0.85)
		_reset_attack_state()
	)

func _start_dash_slash_animation() -> void:
	# 360° 刀光环
	var ring := ColorRect.new()
	ring.size = Vector2(8, 8)
	ring.position = global_position + Vector2(facing_direction * 8, -20)
	ring.pivot_offset = Vector2(-facing_direction * 8, 0)
	ring.color = Color(0.6, 0.4, 1, 0.7)
	ring.z_index = 5
	get_parent().add_child(ring)

	var r := create_tween()
	r.tween_property(ring, "rotation", facing_direction * TAU, 0.18)
	r.parallel().tween_property(ring, "size", Vector2(60, 60), 0.15)
	r.parallel().tween_property(ring, "color:a", 0.0, 0.18)
	r.tween_callback(ring.queue_free)

	# 刀身振动
	var s := create_tween()
	s.tween_property(_sword, "position:x", 8 + facing_direction * 8, 0.04)
	s.tween_property(_sword, "position:x", 8, 0.12)

func _dash_attack_hit_check() -> void:
	if not is_attacking:
		return

	var attack_range := 36.0
	var hit_count := 0

	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy: Node2D in enemies:
		if not is_instance_valid(enemy) or enemy in attack_hit_list:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < attack_range:
			enemy.take_damage(current_atk_dmg, self)
			attack_hit_list.append(enemy)
			hit_count += 1
			var kb: float = sign(enemy.global_position.x - global_position.x)
			if kb == 0: kb = facing_direction
			if enemy is CharacterBody2D:
				enemy.velocity.x += kb * 350
				enemy.velocity.y -= 120
			_spawn_hit_fx(enemy.global_position, enemy)
			EventBus.damage_number_request.emit(current_atk_dmg, enemy.global_position, true)

	if hit_count > 0:
		EventBus.screen_shake_request.emit(4.5, 0.08)
		EventBus.time_scale_request.emit(0.55, 0.05)
		EventBus.hit_effect_request.emit(global_position, "void_slash")


# =============================================================================
# 攻击系统
# =============================================================================
func _on_attack_press() -> void:
	if not can_attack:
		return

	# 冲刺攻击 — 可在冲刺中出刀，附加50%伤害
	if is_dashing and not has_dash_attacked:
		_start_dash_attack()
		return

	# 空中 → 下劈
	if not is_on_floor():
		_start_downstrike()
		return

	# 重攻击中不再接受轻攻击
	if is_heavy_stage > 0:
		return

	# 正在攻击 → buffer下一段
	if is_attacking:
		buffer_combo = true
		return

	# 开始计时（判断轻按/长按）
	is_holding = true
	hold_timer = 0.0

	# 连击判定
	if combo_window_timer > 0:
		attack_combo = wrapi(attack_combo + 1, 0, 3)
	else:
		attack_combo = 0

	_start_light_attack()


func _on_attack_release() -> void:
	if not is_holding:
		return
	is_holding = false

	# 长按且不在攻击动作中 → 重攻击
	if hold_timer >= HEAVY_CHARGE_MIN and is_on_floor() and is_heavy_stage == 0:
		# 取消当前轻攻击（如果还在进行）
		if is_attacking:
			_cancel_attack()
		_start_heavy_attack()


func _start_light_attack() -> void:
	is_attacking = true
	can_attack = false
	buffer_combo = false
	attack_hit_list.clear()

	match attack_combo:
		0:
			attack_timer = ATTACK1_TIME
			current_atk_dmg = GameConstants.ATTACK_DAMAGE_LIGHT
		1:
			attack_timer = ATTACK2_TIME
			current_atk_dmg = GameConstants.ATTACK_DAMAGE_LIGHT * 1.25
		2:
			attack_timer = ATTACK3_TIME
			current_atk_dmg = GameConstants.ATTACK_DAMAGE_LIGHT * 1.8

	combo_window_timer = COMBO_WINDOW

	# 前冲微动
	var dash := create_tween()
	dash.tween_property(self, "velocity:x", facing_direction * 80, 0.06)
	dash.tween_property(self, "velocity:x", input_direction * speed * 0.5, 0.1)

	# 命中判定
	get_tree().create_timer(0.06 + attack_combo * 0.02).timeout.connect(_attack_hit_check)

	# 挥刀动画
	_start_slash_animation()


func _start_slash_animation() -> void:
	var colors := [Color(0.7, 0.8, 1), Color(0.5, 0.7, 1), Color(0.7, 0.35, 1)]
	_sword.color = colors[attack_combo]

	# 刀身振动
	var s := create_tween()
	s.tween_property(_sword, "position:x", 8 + facing_direction * 4, 0.03)
	s.tween_property(_sword, "position:x", 8, 0.08)

	# 身体前倾
	var b := create_tween()
	b.tween_property(_body, "rotation", facing_direction * 0.1, 0.04)
	b.tween_property(_body, "rotation", 0.0, 0.12)

	# 刀光弧线
	var arc := ColorRect.new()
	arc.size = Vector2(24, 16)
	arc.position = global_position + Vector2(facing_direction * 10, -24)
	arc.pivot_offset = Vector2(0, 8)
	arc.rotation = facing_direction * -0.3
	arc.color = Color(0.5, 0.6, 1, 0.5)
	arc.z_index = 4
	get_parent().add_child(arc)

	var a := create_tween()
	a.tween_property(arc, "rotation", facing_direction * 0.5, 0.18)
	a.parallel().tween_property(arc, "color:a", 0.0, 0.2)
	a.parallel().tween_property(arc, "size:x", 32, 0.15)
	a.tween_callback(arc.queue_free)


func _attack_hit_check() -> void:
	if not is_attacking or is_heavy_stage > 0:
		return

	var attack_range := 30.0
	var hit_count := 0

	# 检测范围内的敌人
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy: Node2D in enemies:
		if not is_instance_valid(enemy) or enemy in attack_hit_list:
			continue
		if not enemy.has_method("take_damage"):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		var to_enemy := enemy.global_position - global_position
		# 只打面前的敌人
		if dist < attack_range and sign(to_enemy.x) == facing_direction:
			enemy.take_damage(current_atk_dmg, self)
			attack_hit_list.append(enemy)
			hit_count += 1
			_spawn_hit_fx(enemy.global_position, enemy)
			# 连击击退递增
			var kb := KNOCKBACK_BASE + KNOCKBACK_PER_COMBO * attack_combo
			if enemy is CharacterBody2D:
				enemy.velocity.x += facing_direction * kb
			EventBus.damage_number_request.emit(current_atk_dmg, enemy.global_position, attack_combo == 2)

	if hit_count > 0:
		# 第三段额外震屏+顿帧
		var shake_amp := 2.0 + attack_combo * 2.5
		var shake_dur := 0.05 + attack_combo * 0.02
		var hitstop_scale: float = 0.85 - attack_combo * 0.15
		EventBus.screen_shake_request.emit(shake_amp, shake_dur)
		EventBus.time_scale_request.emit(hitstop_scale, 0.03 + attack_combo * 0.02)
	else:
		# 空挥特效
		_spawn_whiff_fx(global_position + Vector2(facing_direction * 20, -15))


func _start_heavy_attack() -> void:
	is_heavy_stage = 1  # 蓄力
	is_attacking = true
	can_attack = false
	heavy_hit_done = false
	attack_timer = HEAVY_WINDUP
	current_atk_dmg = GameConstants.ATTACK_DAMAGE_HEAVY
	combo_window_timer = 0

	# 蓄力视觉效果
	_body.color = Color(0.25, 0.1, 0.4)
	_sword.color = Color(0.9, 0.25, 1)

	var pulse := create_tween().set_loops()
	pulse.tween_property(_body, "scale", Vector2(1.12, 1.12), 0.15)
	pulse.tween_property(_body, "scale", Vector2(1.0, 1.0), 0.15)


func _start_downstrike() -> void:
	is_attacking = true
	can_attack = false
	attack_hit_list.clear()
	attack_timer = DOWNSTRIKE_TIME
	current_atk_dmg = GameConstants.ATTACK_DAMAGE_DOWNSTRIKE
	combo_window_timer = 0

	velocity.y = 550
	velocity.x = input_direction * speed * 0.25
	_sword.color = Color(0.65, 0.75, 1)

	get_tree().create_timer(0.04).timeout.connect(_attack_hit_check)
	_spawn_downstrike_fx()


func _spawn_downstrike_fx() -> void:
	var line := ColorRect.new()
	line.size = Vector2(2, 18)
	line.position = global_position + Vector2(0, 14)
	line.color = Color(0.5, 0.6, 1, 0.7)
	get_parent().add_child(line)
	var t := create_tween()
	t.tween_property(line, "size:y", 40, 0.2)
	t.parallel().tween_property(line, "color:a", 0.0, 0.2)
	t.tween_callback(line.queue_free)


# =============================================================================
# 攻击状态更新
# =============================================================================
func _update_attack(delta: float) -> void:
	# 蓄力计时
	if is_holding:
		hold_timer += delta

	# 重攻击阶段机
	if is_heavy_stage > 0:
		_update_heavy_stage(delta)
		return

	# 轻攻击计时
	if not is_attacking:
		return

	attack_timer -= delta
	if attack_timer <= 0:
		_on_light_attack_end()

	combo_window_timer = max(0.0, combo_window_timer - delta)


func _update_heavy_stage(delta: float) -> void:
	attack_timer -= delta
	if attack_timer > 0:
		return

	match is_heavy_stage:
		1:  # 蓄力完成 → 前摇
			is_heavy_stage = 2
			attack_timer = HEAVY_WINDUP
			_body.scale = Vector2(1.15, 1.15)
			_spawn_charge_fx()
		2:  # 前摇完成 → 判定
			is_heavy_stage = 3
			attack_timer = HEAVY_ACTIVE
			_heavy_hit_check()
		3:  # 判定结束 → 后摇
			is_heavy_stage = 4
			attack_timer = HEAVY_RECOVERY
			_body.scale = Vector2(1.0, 1.0)
			_body.color = Color(0.06, 0.05, 0.1)
			_sword.color = Color(0.7, 0.7, 0.85)
		4:  # 后摇结束
			is_heavy_stage = 0
			is_attacking = false
			_reset_attack_state()


func _spawn_charge_fx() -> void:
	var burst := ColorRect.new()
	burst.size = Vector2(60, 60)
	burst.position = global_position + Vector2(-30, -30)
	burst.color = Color(0.5, 0.2, 1, 0.3)
	burst.z_index = 3
	get_parent().add_child(burst)
	var b := create_tween()
	b.tween_property(burst, "size", Vector2(100, 100), 0.25)
	b.parallel().tween_property(burst, "color:a", 0.0, 0.25)
	b.parallel().tween_property(burst, "position", global_position + Vector2(-50, -50), 0.25)
	b.tween_callback(burst.queue_free)


func _heavy_hit_check() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var hit_count := 0

	for enemy: Node2D in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		if enemy in attack_hit_list:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < 50:
			enemy.take_damage(current_atk_dmg, self)
			attack_hit_list.append(enemy)
			hit_count += 1
			var kb: float = sign(enemy.global_position.x - global_position.x)
			if enemy is CharacterBody2D:
				enemy.velocity.x += kb * 500
			_spawn_hit_fx(enemy.global_position, enemy)
			EventBus.damage_number_request.emit(current_atk_dmg, enemy.global_position, true)

	if hit_count > 0:
		EventBus.screen_shake_request.emit(8.0, 0.15)
		EventBus.time_scale_request.emit(0.3, 0.08)
	else:
		_spawn_whiff_fx(global_position + Vector2(facing_direction * 25, -10))


func _on_light_attack_end() -> void:
	if buffer_combo:
		buffer_combo = false
		attack_combo = wrapi(attack_combo + 1, 0, 3)
		_start_light_attack()
		return

	is_attacking = false
	_sword.color = Color(0.7, 0.7, 0.85)

	if combo_window_timer > 0:
		can_attack = true
		get_tree().create_timer(combo_window_timer).timeout.connect(_reset_if_inactive)
	else:
		_reset_attack_state()

	if current_state == PlayerState.ATTACKING:
		current_state = PlayerState.IDLE


func _reset_if_inactive() -> void:
	if not is_attacking and combo_window_timer <= 0:
		_reset_attack_state()


func _reset_attack_state() -> void:
	attack_combo = 0
	combo_window_timer = 0
	buffer_combo = false
	can_attack = true
	if current_state == PlayerState.ATTACKING:
		current_state = PlayerState.IDLE


func _cancel_attack() -> void:
	is_attacking = false
	is_heavy_stage = 0
	is_holding = false
	buffer_combo = false
	attack_hit_list.clear()
	_body.scale = Vector2(1, 1)
	_body.color = Color(0.06, 0.05, 0.1)
	_sword.color = Color(0.7, 0.7, 0.85)
	_reset_attack_state()


# =============================================================================
# 特效生成
# =============================================================================
func _spawn_hit_fx(pos: Vector2, enemy: Node2D = null) -> void:
	# 命中火花
	for _i: int in range(5):
		var spark := ColorRect.new()
		spark.size = Vector2(3, 3)
		spark.position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		spark.color = Color(0.8, 0.85, 1)
		get_parent().add_child(spark)
		var s := create_tween()
		var dx := randf_range(-60, 60)
		var dy := randf_range(-60, 20)
		s.tween_property(spark, "position", spark.position + Vector2(dx, dy), 0.25)
		s.parallel().tween_property(spark, "color:a", 0.0, 0.25)
		s.parallel().tween_property(spark, "size", Vector2.ZERO, 0.25)
		s.tween_callback(spark.queue_free)
	# 敌人白色闪光
		if enemy:
			enemy.modulate = Color(2, 2, 2, 1)
			await get_tree().create_timer(0.05).timeout
			if is_instance_valid(enemy):
				enemy.modulate = Color(1, 1, 1, 1)

	# 圆形波纹
	var ripple := ColorRect.new()
	ripple.size = Vector2(4, 4)
	ripple.position = pos + Vector2(-2, -2)
	ripple.color = Color(0.6, 0.7, 1, 0.6)
	get_parent().add_child(ripple)
	var r := create_tween()
	r.tween_property(ripple, "size", Vector2(24, 24), 0.2)
	r.parallel().tween_property(ripple, "position", pos + Vector2(-12, -12), 0.2)
	r.parallel().tween_property(ripple, "color:a", 0.0, 0.2)
	r.tween_callback(ripple.queue_free)


func _spawn_whiff_fx(pos: Vector2) -> void:
	var swipe := ColorRect.new()
	swipe.size = Vector2(18, 3)
	swipe.position = pos
	swipe.color = Color(0.4, 0.5, 1, 0.35)
	get_parent().add_child(swipe)
	var t := create_tween()
	t.tween_property(swipe, "position:x", pos.x + facing_direction * 30, 0.15)
	t.parallel().tween_property(swipe, "color:a", 0.0, 0.2)
	t.tween_callback(swipe.queue_free)


# =============================================================================
# 闪避 — 支持攻击取消
# =============================================================================
func _start_dodge() -> void:
	if is_attacking:
		_cancel_attack()

	is_dodging = true
	dodge_cooldown_timer = GameConstants.DODGE_COOLDOWN
	current_state = PlayerState.DODGING
	if hurtbox:
		hurtbox.monitoring = false

	# 后空翻效果
	var dir := input_direction if input_direction != 0 else -facing_direction
	velocity.x = dir * 250
	velocity.y = -80

	get_tree().create_timer(GameConstants.DODGE_DURATION).timeout.connect(_end_dodge)


func _end_dodge() -> void:
	is_dodging = false
	if hurtbox:
		hurtbox.monitoring = true
	current_state = PlayerState.IDLE


# =============================================================================
# 技能
# =============================================================================
func _cast_skill(skill_id: int) -> void:
	if not GameManager.use_skill(skill_id):
		return

	if is_attacking:
		_cancel_attack()

	match skill_id:
		1:
			_skill_mech_blast()
		2:
			_skill_void_slash()


func _skill_mech_blast() -> void:
	can_attack = false
	is_attacking = true

	# 冲击波视觉效果
	var wave := ColorRect.new()
	wave.size = Vector2(8, 20)
	wave.position = global_position + Vector2(facing_direction * 12, -20)
	wave.color = Color(0.3, 0.5, 1, 0.7)
	wave.z_index = 5
	get_parent().add_child(wave)

	var w := create_tween()
	w.tween_property(wave, "size:x", 80, 0.2)
	w.parallel().tween_property(wave, "position:x", global_position.x + facing_direction * 80, 0.2)
	w.parallel().tween_property(wave, "color:a", 0.0, 0.25)
	w.tween_callback(wave.queue_free)

	# 伤害判定
	get_tree().create_timer(0.1).timeout.connect(func():
		var enemies := get_tree().get_nodes_in_group("enemy")
		for enemy: Node2D in enemies:
			if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
				continue
			var dist := global_position.distance_to(enemy.global_position)
			var to_enemy := enemy.global_position - global_position
			if dist < GameConstants.SKILL1_RANGE and sign(to_enemy.x) == facing_direction:
				enemy.take_damage(GameConstants.SKILL1_DAMAGE, self)
				if enemy is CharacterBody2D:
					enemy.velocity.x += facing_direction * GameConstants.SKILL1_KNOCKBACK
				EventBus.damage_number_request.emit(GameConstants.SKILL1_DAMAGE, enemy.global_position, false)
				_spawn_hit_fx(enemy.global_position, enemy)
		EventBus.screen_shake_request.emit(4.0, 0.08)
	)

	get_tree().create_timer(0.3).timeout.connect(func():
		is_attacking = false
		can_attack = true
	)


func _skill_void_slash() -> void:
	can_attack = false
	is_attacking = true

	# 虚空斩环
	for i: int in range(3):
		get_tree().create_timer(i * 0.08).timeout.connect(func():
			var ring := ColorRect.new()
			ring.size = Vector2(10, 10)
			ring.position = global_position + Vector2(-5, -20)
			ring.color = Color(0.6, 0.3, 1, 0.6)
			ring.z_index = 5
			get_parent().add_child(ring)
			var r := create_tween()
			r.tween_property(ring, "size", Vector2(70, 70), 0.35)
			r.parallel().tween_property(ring, "position", global_position + Vector2(-35, -45), 0.35)
			r.parallel().tween_property(ring, "color:a", 0.0, 0.35)
			r.tween_callback(ring.queue_free)
		)

	# AOE伤害
	get_tree().create_timer(0.2).timeout.connect(func():
		var enemies := get_tree().get_nodes_in_group("enemy")
		var hit_count := 0
		for enemy: Node2D in enemies:
			if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
				continue
			if global_position.distance_to(enemy.global_position) < GameConstants.SKILL2_RANGE:
				enemy.take_damage(GameConstants.SKILL2_DAMAGE, self)
				hit_count += 1
				EventBus.damage_number_request.emit(GameConstants.SKILL2_DAMAGE, enemy.global_position, false)
				_spawn_hit_fx(enemy.global_position, enemy)
		if hit_count > 0:
			EventBus.screen_shake_request.emit(5.0, 0.1)
			EventBus.time_scale_request.emit(0.6, 0.05)
	)

	get_tree().create_timer(0.45).timeout.connect(func():
		is_attacking = false
		can_attack = true
	)


# =============================================================================
# 受伤/死亡
# =============================================================================
func _on_damaged(_amount: float, source: Node2D) -> void:
	_cancel_attack()
	current_state = PlayerState.STUNNED
	if source:
		velocity = (global_position - source.global_position).normalized() * 300
	get_tree().create_timer(0.3).timeout.connect(func(): current_state = PlayerState.IDLE)


func _on_died() -> void:
	current_state = PlayerState.DEAD
	velocity = Vector2.ZERO


func _on_area_entered(area: Area2D) -> void:
	if area.has_meta("death_zone"):
		GameManager.damage_player(9999, self)
	elif area.has_meta("is_orb"):
		_collect_orb(area)

func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D and body.has_meta("is_spike"):
		GameManager.damage_player(20, body)
		velocity.y = -300
		_modulate_hurt()

func _modulate_hurt() -> void:
	var t: Tween = create_tween()
	t.tween_property(_body, "modulate", Color.RED, 0.05)
	t.tween_property(_body, "modulate", Color.WHITE, 0.1)

func _collect_orb(orb: Area2D) -> void:
	orb.queue_free()
	_orb_count += 1
	EventBus.orb_collected.emit(_orb_count)
	var t: Tween = create_tween()
	t.tween_property(_eye, "color", Color(0, 1, 0.8, 1), 0.1)
	t.tween_property(_eye, "color", Color(0, 0.85, 1, 1), 0.3)

func get_orb_count() -> int:
	return _orb_count

func take_damage(amount: float, source: Node2D) -> void:
	if is_dodging or is_dashing:
		return
	GameManager.damage_player(amount, source)
