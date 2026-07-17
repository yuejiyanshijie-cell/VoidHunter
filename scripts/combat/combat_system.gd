# combat_system.gd - 战斗系统
# 伤害数字 + 命中特效 + 屏幕震动 + 顿帧效果
extends Node

var world_node: Node2D
var camera: Camera2D


func initialize(world: Node2D, cam: Camera2D) -> void:
	world_node = world
	camera = cam
	EventBus.damage_number_request.connect(_on_damage_number)
	EventBus.hit_effect_request.connect(_on_hit_effect)
	EventBus.screen_shake_request.connect(_on_shake)
	EventBus.time_scale_request.connect(_on_time_scale)


# =============================================================================
# 伤害数字 — 浮动上升淡出
# =============================================================================
func _on_damage_number(amount: float, pos: Vector2, is_crit: bool) -> void:
	var label := Label.new()
	label.text = str(int(ceil(amount)))
	label.add_theme_font_size_override("font_size", 18 if is_crit else 14)
	label.add_theme_color_override("font_color", Color.YELLOW if is_crit else Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.position = pos + Vector2(randf_range(-15, 15), -20)
	label.z_index = 100
	world_node.add_child(label)

	var t := create_tween().set_parallel()
	t.tween_property(label, "position:y", pos.y - 50, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:x", pos.x + randf_range(-15, 15), 0.6)
	t.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.25)
	t.chain().tween_callback(label.queue_free)

	# 暴击额外效果
	if is_crit:
		var ring := ColorRect.new()
		ring.size = Vector2(30, 30)
		ring.position = pos + Vector2(-15, -15)
		ring.color = Color(1, 0.85, 0.2, 0.5)
		ring.z_index = 99
		world_node.add_child(ring)
		var rt := create_tween()
		rt.tween_property(ring, "size", Vector2(60, 60), 0.2)
		rt.parallel().tween_property(ring, "position", pos + Vector2(-30, -30), 0.2)
		rt.parallel().tween_property(ring, "color:a", 0.0, 0.2)
		rt.tween_callback(ring.queue_free)


# =============================================================================
# 命中特效
# =============================================================================
func _on_hit_effect(pos: Vector2, type: StringName) -> void:
	match type:
		"hit":
			_hit_sparks(pos)
		"slash":
			_slash_trail(pos)
		"blast":
			_blast_wave(pos)
		"void_slash":
			_void_ring(pos)
		_:
			_hit_sparks(pos)


func _hit_sparks(pos: Vector2) -> void:
	for _i: int in range(4):
		var s := ColorRect.new()
		s.size = Vector2(3, 3)
		s.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		s.color = Color(0.9, 0.9, 1)
		s.z_index = 50
		world_node.add_child(s)
		var t := create_tween()
		var dx := randf_range(-50, 50)
		var dy := randf_range(-40, 20)
		t.tween_property(s, "position", s.position + Vector2(dx, dy), 0.2)
		t.parallel().tween_property(s, "size", Vector2.ZERO, 0.2)
		t.parallel().tween_property(s, "color:a", 0.0, 0.2)
		t.tween_callback(s.queue_free)


func _slash_trail(pos: Vector2) -> void:
	var arc := ColorRect.new()
	arc.size = Vector2(20, 4)
	arc.position = pos
	arc.color = Color(0.4, 0.5, 1, 0.5)
	arc.z_index = 50
	world_node.add_child(arc)
	var t := create_tween()
	t.tween_property(arc, "size:x", 40, 0.12)
	t.parallel().tween_property(arc, "color:a", 0.0, 0.15)
	t.tween_callback(arc.queue_free)


func _blast_wave(pos: Vector2) -> void:
	var wave := ColorRect.new()
	wave.size = Vector2(10, 6)
	wave.position = pos + Vector2(-5, -3)
	wave.color = Color(0.3, 0.6, 1, 0.5)
	wave.z_index = 50
	world_node.add_child(wave)
	var t := create_tween()
	t.tween_property(wave, "size", Vector2(60, 20), 0.2)
	t.parallel().tween_property(wave, "position", pos + Vector2(-30, -10), 0.2)
	t.parallel().tween_property(wave, "color:a", 0.0, 0.2)
	t.tween_callback(wave.queue_free)


func _void_ring(pos: Vector2) -> void:
	for r: int in range(3):
		var ring := ColorRect.new()
		ring.size = Vector2(20, 20)
		ring.position = pos + Vector2(-10, -10)
		ring.color = Color(0.5, 0.25, 1, 0.4)
		ring.z_index = 50
		world_node.add_child(ring)
		var t := create_tween()
		t.tween_property(ring, "size", Vector2(60, 60), 0.3)
		t.parallel().tween_property(ring, "position", pos + Vector2(-30, -30), 0.3)
		t.parallel().tween_property(ring, "color:a", 0.0, 0.3)
		t.tween_callback(ring.queue_free)


# =============================================================================
# 屏幕震动
# =============================================================================
func _on_shake(amplitude: float, duration: float) -> void:
	if not camera:
		return
	var start := camera.global_position
	var count: int = max(1, int(duration * 50))
	var t := create_tween().set_loops(count)
	t.tween_method(
		func(_v): camera.global_position = start + Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		),
		0.0, 0.0, 0.02
	)
	t.finished.connect(func(): camera.global_position = start)


# =============================================================================
# 顿帧
# =============================================================================
func _on_time_scale(scale: float, duration: float) -> void:
	var orig := Engine.time_scale
	Engine.time_scale = max(scale, 0.1)
	get_tree().create_timer(duration * scale, true, false, true).timeout.connect(
		func(): Engine.time_scale = orig
	)
