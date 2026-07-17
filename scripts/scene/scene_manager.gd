# scene_manager.gd - 场景管理器
extends Node2D

@export var player_scene: PackedScene

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: Camera2D = $Camera2D
@onready var combat_system_node: Node = $CombatSystem
@onready var enemy_container: Node = $EnemyContainer
@onready var level_builder: Node2D = $LevelBuilder


func _ready() -> void:
	# 关卡已通过场景中的LevelBuilder节点构建
	if combat_system_node.has_method("initialize"):
		combat_system_node.initialize(self, camera)

	_spawn_player()
	_spawn_test_enemies()
	EventBus.level_loaded.emit("demo_level")


func _spawn_player() -> void:
	if not player_scene:
		push_error("Player scene not assigned!")
		return

	var player: CharacterBody2D = player_scene.instantiate()
	player.global_position = player_spawn.global_position if player_spawn else Vector2(100, 420)
	add_child(player)
	player.add_to_group("player")
	camera.set("follow_target", player)

	var ui_scene: PackedScene = load("res://scenes/ui.tscn")
	var ui_instance: CanvasLayer = ui_scene.instantiate()
	add_child(ui_instance)


func _spawn_test_enemies() -> void:
	var bugs: PackedScene = load("res://scenes/enemy_bug.tscn")
	var guard: PackedScene = load("res://scenes/enemy_guard.tscn")
	var boss: PackedScene = load("res://scenes/enemy_boss.tscn")

	# 机械虫群
	var e1: CharacterBody2D = bugs.instantiate()
	e1.global_position = Vector2(350, 440)
	enemy_container.add_child(e1)

	var e2: CharacterBody2D = bugs.instantiate()
	e2.global_position = Vector2(500, 440)
	enemy_container.add_child(e2)

	var e3: CharacterBody2D = bugs.instantiate()
	e3.global_position = Vector2(650, 440)
	enemy_container.add_child(e3)

	# 能量守卫（远程）
	var g1: CharacterBody2D = guard.instantiate()
	g1.global_position = Vector2(900, 440)
	enemy_container.add_child(g1)

	var g2: CharacterBody2D = guard.instantiate()
	g2.global_position = Vector2(1300, 430)
	enemy_container.add_child(g2)

	# Boss
	var b1: CharacterBody2D = boss.instantiate()
	b1.global_position = Vector2(1700, 430)
	enemy_container.add_child(b1)


func transition_to_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
