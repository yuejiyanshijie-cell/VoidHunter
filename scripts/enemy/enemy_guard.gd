# enemy_guard.gd - 能量守卫
# 行为：巡逻，发现玩家后保持距离远程射击，被近身后后撤
extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, MAINTAIN_DISTANCE, ATTACK, STUNNED, DEAD }

var current_state: State = State.IDLE
var current_health: float = 80.0
var max_health: float = 80.0
var move_speed: float = 60.0
var attack_damage: float = 15.0
var knockback_resist: float = 2.0
var detection_range: float = 350.0
var ideal_distance: float = 150.0  # 和玩家保持的理想距离

var player_ref: CharacterBody2D = null
var spawn_position: Vector2
var facing_direction: float = -1.0
var stun_timer: float = 0.0
var patrol_dir: float = -1.0
var patrol_timer: float = 0.0
var shoot_cooldown: float = 0.0
const SHOOT_INTERVAL: float = 1.8

# 视觉
var _body: ColorRect
var _core: ColorRect


func _ready() -> void:
	current_health = max_health
	spawn_position = global_position
	_create_visual()


func _create_visual() -> void:
	_body = ColorRect.new()
	_body.size = Vector2(22, 22)
	_body.position = Vector2(-11, -11)
	_body.color = Color(0.3, 0.3, 0.6, 1)
	add_child(_body)

	_core = ColorRect.new()
	_core.size = Vector2(8, 8)
	_core.position = Vector2(-4, -4)
	_core.color = Color(0.5, 0.4, 1, 1)
	_body.add_child(_core)


func _process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	stun_timer = max(0.0, stun_timer - delta)
	if stun_timer <= 0 and current_state == State.STUNNED:
		_set_state(State.IDLE)

	shoot_cooldown = max(0.0, shoot_cooldown - delta)

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

	if current_state != State.STUNNED:
		move_and_slide()

	if abs(velocity.x) > 5:
		facing_direction = sign(velocity.x)
		_body.scale.x = facing_direction


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
	patrol_timer += delta
	if patrol_timer > 2.5:
		patrol_timer = 0.0
		patrol_dir *= -1
	velocity.x = patrol_dir * move_speed * 0.3


func _chase_player() -> void:
	if not player_ref:
		return
	var dist: float = global_position.distance_to(player_ref.global_position)
	var dir: float = sign(player_ref.global_position.x - global_position.x)

	if dist > ideal_distance + 50:
		# 太远→靠近
		velocity.x = dir * move_speed
	elif dist < ideal_distance - 50:
		# 太近→后撤
		velocity.x = -dir * move_speed
	else:
		# 理想距离→停住射击
		velocity.x = 0
		if shoot_cooldown <= 0:
			_shoot()

	# 更新朝向
	if abs(dir) > 0.01:
		facing_direction = dir


func _shoot() -> void:
	if not player_ref:
		return
	shoot_cooldown = SHOOT_INTERVAL

	# 生成能量弹
	var bullet := Area2D.new()
	bullet.name = "Bullet"
	bullet.position = global_position + Vector2(facing_direction * 16, -6)

	var bullet_script := load("res://scripts/enemy/enemy_bullet.gd")
	bullet.set_script(bullet_script)
	bullet.damage = attack_damage
	bullet.source = self
	bullet.velocity = Vector2(facing_direction * 200.0, 0)
	bullet.lifetime = 2.0

	# 碰撞体
	var coll := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	coll.shape = rect
	bullet.add_child(coll)

	get_parent().add_child(bullet)


func _set_state(s: State) -> void:
	current_state = s
	if s == State.IDLE:
		get_tree().create_timer(0.5).timeout.connect(
			func(): if current_state == State.IDLE: _set_state(State.PATROL)
		)
	elif s == State.PATROL:
		velocity.x = patrol_dir * move_speed * 0.3


# ---- Damage ----
func take_damage(amount: float, source: Node2D) -> void:
	if current_state == State.DEAD:
		return
	current_health = max(0.0, current_health - amount)

	if source and source is CharacterBody2D:
		var kb: float = sign(global_position.x - source.global_position.x) * (150.0 / knockback_resist)
		velocity.x = kb

	current_state = State.STUNNED
	stun_timer = 0.25

	var t: Tween = create_tween()
	t.tween_property(_body, "modulate", Color.WHITE, 0.06)
	t.tween_property(_body, "modulate", Color(1, 1, 1, 1), 0.1)

	EventBus.damage_number_request.emit(amount, global_position, false)

	if current_health <= 0:
		_die()


func _die() -> void:
	current_state = State.DEAD
	EventBus.enemy_killed.emit(self, global_position)
	var t: Tween = create_tween()
	t.tween_property(_body, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)
