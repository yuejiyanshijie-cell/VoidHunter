# enemy_bullet.gd - 能量弹（能量守卫发射）
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 15.0
var source: Node2D = null
var lifetime: float = 3.0

@onready var visual: ColorRect = $ColorRect


func _ready() -> void:
	if visual:
		visual.color = Color(0.3, 0.2, 1, 1)
	else:
		var v: ColorRect = ColorRect.new()
		v.size = Vector2(8, 6)
		v.position = Vector2(-4, -3)
		v.color = Color(0.3, 0.2, 1, 1)
		add_child(v)
		visual = v

	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit_area)


func _process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()


func _on_hit(body: Node2D) -> void:
	if body == source:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, source)
		EventBus.hit_effect_request.emit(global_position, "hit")
		_queue_free_with_fx()


func _on_hit_area(area: Area2D) -> void:
	var body: Node2D = area.get_parent()
	if body == source:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, source)
		EventBus.hit_effect_request.emit(global_position, "hit")
		_queue_free_with_fx()


func _queue_free_with_fx() -> void:
	# 爆炸粒子
	var t: Tween = create_tween()
	t.tween_property(visual, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
	set_process(false)
