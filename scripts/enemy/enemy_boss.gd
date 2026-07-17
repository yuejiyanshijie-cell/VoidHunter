# enemy_boss.gd - 变异机械兽(Boss)
# 多阶段AI：Phase1 近战冲撞+跳跃，Phase2(<50%血量) 增加远程攻击
extends CharacterBody2D

enum BossPhase { PHASE1, PHASE2 }

var current_health: float = 500.0
var max_health: float = 500.0
var attack_damage: float = 25.0
var move_speed: float = 150.0
var knockback_resist: float = 5.0
var detection_range: float = 500.0
var current_phase: BossPhase = BossPhase.PHASE1

var player_ref: CharacterBody2D = null
var facing_direction: float = -1.0
var stun_timer: float = 0.0
var is_stunned: bool = false

# AI行为
var action_timer: float = 0.0
var current_action: StringName = "idle"
var charge_speed: float = 400.0
var is_charging: bool = false
var jump_timer: float = 0.0
var next_action_time: float = 0.0

# 视觉
var _body: ColorRect
var _armor: ColorRect
var _eyes: Array[ColorRect] = []
var _health_bar: ColorRect
var _health_bg: ColorRect


func _ready() -> void:
	current_health = max_health
	_create_visual()


func _create_visual() -> void:
	# 大身体
	_body = ColorRect.new()
	_body.size = Vector2(40, 30)
	_body.position = Vector2(-20, -15)
	_body.color = Color(0.15, 0.15, 0.25, 1)
	add_child(_body)

	# 装甲层
	_armor = ColorRect.new()
	_armor.size = Vector2(38, 8)
	_armor.position = Vector2(-19, -11)
	_armor.color = Color(0.55, 0.15, 0.15, 1)
	_body.add_child(_armor)

	# 多只眼睛
	for i: int in range(3):
		var eye: ColorRect = ColorRect.new()
		eye.size = Vector2(4, 3)
		eye.position = Vector2(-8 + i * 6, -7)
		eye.color = Color(0.6, 0.2, 1, 1)
		_body.add_child(eye)
		_eyes.append(eye)

	# 爪子
	for side: int in [-1, 1]:
		var claw: ColorRect = ColorRect.new()
		claw.size = Vector2(6, 12)
		claw.position = Vector2(side * 18, 10)
		claw.color = Color(0.5, 0.35, 0.2, 1)
		_body.add_child(claw)

	# 血条
	_health_bg = ColorRect.new()
	_health_bg.size = Vector2(60, 6)
	_health_bg.position = Vector2(-30, -22)
	_health_bg.color = Color(0.2, 0.05, 0.05, 1)
	add_child(_health_bg)

	_health_bar = ColorRect.new()
	_health_bar.size = Vector2(60, 6)
	_health_bar.position = Vector2(-30, -22)
	_health_bar.color = Color(0.9, 0.2, 0.1, 1)
	add_child(_health_bar)


func _process(delta: float) -> void:
	if current_health <= 0:
		return

	# 阶段切换
	var hp_ratio: float = current_health / max_health
	if hp_ratio <= 0.5 and current_phase == BossPhase.PHASE1:
		current_phase = BossPhase.PHASE2
		_enter_phase2()

	_update_phase(delta)
	_update_health_bar()
	_update_visual(delta)

	# 硬直计时
	if stun_timer > 0:
		stun_timer = max(0.0, stun_timer - delta)
		if stun_timer <= 0:
			is_stunned = false


func _physics_process(delta: float) -> void:
	if current_health <= 0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_stunned:
		velocity.x *= 0.9
	else:
		velocity.y += GameConstants.GRAVITY * delta
		velocity.y = min(velocity.y, GameConstants.TERMINAL_VELOCITY)

	move_and_slide()

	if not is_on_floor() and not is_charging:
		velocity.x *= 0.98  # 空中减速


func _update_phase(delta: float) -> void:
	if is_stunned:
		return

	# 搜索玩家
	if not player_ref:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0]

	if not player_ref:
		return

	# 面朝玩家
	var to_player: float = sign(player_ref.global_position.x - global_position.x)
	if abs(to_player) > 0.01:
		facing_direction = to_player
		_body.scale.x = facing_direction

	# AI决策
	action_timer -= delta
	if action_timer <= 0:
		_decide_action()

	_execute_action(delta)


func _decide_action() -> void:
	var rand_val: float = randf()
	var dist: float = global_position.distance_to(player_ref.global_position) if player_ref else 500

	if dist > 200:
		# 远距离 → 冲撞或跳跃
		current_action = "charge" if rand_val < 0.6 else "jump"
	else:
		# 近距离 → 攻击
		if current_phase == BossPhase.PHASE2 and rand_val < 0.4:
			current_action = "area_blast"
		elif rand_val < 0.5:
			current_action = "charge"
		else:
			current_action = "slam"

	action_timer = randf_range(0.5, 1.5)


func _execute_action(delta: float) -> void:
	match current_action:
		"idle":
			velocity.x = 0
		"charge":
			_execute_charge()
		"jump":
			_execute_jump(delta)
		"slam":
			_execute_slam()
		"area_blast":
			_execute_area_blast()


func _execute_charge() -> void:
	if not player_ref:
		return
	if not is_charging:
		is_charging = true
		_body.color = Color(0.3, 0.1, 0.1, 1)

	var dir: float = sign(player_ref.global_position.x - global_position.x)
	velocity.x = dir * charge_speed

	# 撞到玩家
	if player_ref and global_position.distance_to(player_ref.global_position) < 30:
		player_ref.take_damage(attack_damage, self)
		EventBus.screen_shake_request.emit(5.0, 0.1)
		is_charging = false
		_body.color = Color(0.15, 0.15, 0.25, 1)
		current_action = "idle"
		action_timer = 1.0


func _execute_jump(delta: float) -> void:
	if is_on_floor() and jump_timer <= 0:
		velocity.y = -500
		jump_timer = 0.5
	elif not is_on_floor():
		if player_ref:
			var dir: float = sign(player_ref.global_position.x - global_position.x)
			velocity.x = dir * 200
		jump_timer -= delta


func _execute_slam() -> void:
	if not player_ref:
		return
	# 跟随玩家走位
	var dir: float = sign(player_ref.global_position.x - global_position.x)
	velocity.x = dir * move_speed

	if global_position.distance_to(player_ref.global_position) < 26:
		player_ref.take_damage(attack_damage * 0.6, self)
		current_action = "idle"
		action_timer = 0.8


func _execute_area_blast() -> void:
	# Phase2技能：范围爆炸
	if not player_ref:
		return
	# 发光预警
	var flash: Tween = create_tween()
	flash.tween_property(_body, "modulate", Color(0.8, 0.4, 1, 1), 0.3)
	flash.tween_property(_body, "modulate", Color(1, 1, 1, 1), 0.1)

	# AOE伤害
	get_tree().create_timer(0.3).timeout.connect(
		func():
			if player_ref and is_instance_valid(player_ref):
				if global_position.distance_to(player_ref.global_position) < 100:
					player_ref.take_damage(attack_damage * 1.5, self)
					EventBus.screen_shake_request.emit(8.0, 0.15)
	)
	current_action = "idle"
	action_timer = 2.0


func _enter_phase2() -> void:
	print("[Boss] Entering Phase 2!")
	_armor.color = Color(0.7, 0.2, 0.6, 1)  # 变色
	for eye in _eyes:
		eye.color = Color(1, 0.2, 0.2, 1)
	charge_speed = 500  # 更快
	move_speed = 200
	EventBus.screen_shake_request.emit(6.0, 0.2)


func _update_health_bar() -> void:
	var ratio: float = current_health / max_health
	_health_bar.size.x = 60 * ratio


func _update_visual(delta: float) -> void:
	# 眼睛闪烁
	var t: float = Time.get_ticks_msec() / 1000.0
	for i: int in range(_eyes.size()):
		var alpha: float = 0.5 + 0.5 * sin(t * 6 + i * 2)
		_eyes[i].modulate.a = alpha

	# 受伤恢复
	if not is_stunned and _body.modulate.r < 0.9:
		_body.modulate = _body.modulate.lerp(Color(1, 1, 1, 1), delta * 10)


# ---- Damage ----
func take_damage(amount: float, source: Node2D) -> void:
	if current_health <= 0:
		return
	current_health = max(0.0, current_health - amount)

	# 击退抗性强
	if source and source is CharacterBody2D:
		var kb: float = sign(global_position.x - source.global_position.x) * (80.0 / knockback_resist)
		velocity.x = kb

	is_stunned = true
	stun_timer = 0.15
	_body.modulate = Color.WHITE
	is_charging = false

	EventBus.damage_number_request.emit(amount, global_position + Vector2(0, -20), false)
	print("[Boss] HP: ", current_health, "/", max_health)

	if current_health <= 0:
		_die()


func _die() -> void:
	print("[Boss] Defeated!")
	EventBus.enemy_killed.emit(self, global_position)
	EventBus.boss_defeated.emit()
	EventBus.screen_shake_request.emit(10.0, 0.3)
	EventBus.time_scale_request.emit(0.3, 0.3)

	var t: Tween = create_tween()
	t.tween_property(_body, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
