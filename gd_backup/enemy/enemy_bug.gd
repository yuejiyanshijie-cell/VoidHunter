# enemy_bug.gd - 外星机械虫
# 行为：巡逻 → 发现玩家后快速追击 → 近战碰撞伤害
extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, ATTACK, STUNNED, DEAD }

var current_state: State = State.IDLE
var current_health: float = 30.0
var max_health: float = 30.0
var move_speed: float = 120.0
var attack_damage: float = 10.0
var knockback_resist: float = 0.5
var detection_range: float = 250.0

var player_ref: CharacterBody2D = null
var spawn_position: Vector2
var facing_direction: float = -1.0
var stun_timer: float = 0.0
var patrol_dir: float = -1.0
var patrol_timer: float = 0.0
var attack_cooldown: float = 0.0
var can_attack: bool = true

# 视觉
var _body: ColorRect
var _eye: ColorRect


func _ready() -> void:
	current_health = max_health
	spawn_position = global_position
	_create_visual()


func _create_visual() -> void:
	_body = ColorRect.new()
	_body.size = Vector2(20, 10)
	_body.position = Vector2(-10, -5)
	_body.color = Color(0.4, 0.3, 0.2, 1)
	add_child(_body)

	_eye = ColorRect.new()
	_eye.size = Vector2(3, 3)
	_eye.position = Vector2(6, -3)
	_eye.color = Color(1, 0.2, 0.1, 1)
	_body.add_child(_eye)


func _process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	_update_timers(delta)

	match current_state:
		State.IDLE, State.PATROL:
			_search_for_player()
		State.CHASE:
			if player_ref:
				_chase_player()
			else:
				_set_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity.y += GameConstants.GRAVITY * delta
	velocity.y = min(velocity.y, GameConstants.TERMINAL_VELOCITY)

	match current_state:
		State.PATROL:
			_patrol_move(delta)
		State.CHASE:
			pass  # velocity set in _chase_player

	if current_state != State.STUNNED:
		move_and_slide()

	if velocity.x != 0:
		facing_direction = sign(velocity.x)
		_body.scale.x = facing_direction


func _update_timers(delta: float) -> void:
	if stun_timer > 0:
		stun_timer = max(0.0, stun_timer - delta)
		if stun_timer <= 0 and current_state == State.STUNNED:
			_set_state(State.IDLE)

	if attack_cooldown > 0:
		attack_cooldown = max(0.0, attack_cooldown - delta)
		if attack_cooldown <= 0:
			can_attack = true

	if current_state == State.PATROL:
		patrol_timer += delta
		if patrol_timer > 2.0:
			patrol_timer = 0.0
			patrol_dir *= -1


func _search_for_player() -> void:
	if player_ref:
		if global_position.distance_to(player_ref.global_position) > detection_range * 1.5:
			player_ref = null
			_set_state(State.PATROL)
	else:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p: Node2D = players[0]
			if global_position.distance_to(p.global_position) < detection_range:
				player_ref = p
				_set_state(State.CHASE)


func _patrol_move(delta: float) -> void:
	velocity.x = patrol_dir * move_speed * 0.4  # 巡逻速度慢


func _chase_player() -> void:
	if not player_ref:
		return
	var dir: float = sign(player_ref.global_position.x - global_position.x)
	velocity.x = dir * move_speed

	# 接触伤害
	if global_position.distance_to(player_ref.global_position) < 24 and can_attack:
		_melee_attack()


func _melee_attack() -> void:
	if not player_ref:
		return
	can_attack = false
	attack_cooldown = 0.8
	player_ref.take_damage(attack_damage, self)
	EventBus.hit_effect_request.emit(player_ref.global_position, "hit")
	# 攻击后小幅后撤
	velocity.x = -facing_direction * 100


func _set_state(s: State) -> void:
	if current_state == s:
		return
	current_state = s
	match s:
		State.IDLE:
			get_tree().create_timer(0.5).timeout.connect(
				func(): if current_state == State.IDLE: _set_state(State.PATROL)
			)
		State.PATROL:
			velocity.x = patrol_dir * move_speed * 0.4


# ---- Damage ----
func take_damage(amount: float, source: Node2D) -> void:
	if current_state == State.DEAD:
		return
	current_health = max(0.0, current_health - amount)

	if source and source is CharacterBody2D:
		var kb: float = sign(global_position.x - source.global_position.x) * (200.0 / knockback_resist)
		velocity.x = kb

	current_state = State.STUNNED
	stun_timer = 0.2

	_flash()
	EventBus.damage_number_request.emit(amount, global_position, false)

	if current_health <= 0:
		_die()


func _flash() -> void:
	var t: Tween = create_tween()
	t.tween_property(_body, "modulate", Color.WHITE, 0.06)
	t.tween_property(_body, "modulate", Color(1, 1, 1, 1), 0.1)


func _die() -> void:
	current_state = State.DEAD
	EventBus.enemy_killed.emit(self, global_position)
	var t: Tween = create_tween()
	t.tween_property(_body, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
