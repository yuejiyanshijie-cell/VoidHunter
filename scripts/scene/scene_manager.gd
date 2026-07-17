# scene_manager.gd - 场景管理器
extends Node2D

@export var player_scene: PackedScene

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: Camera2D = $Camera2D
@onready var combat_system_node: Node = $CombatSystem
@onready var enemy_container: Node = $EnemyContainer
@onready var level_builder: Node2D = $LevelBuilder

var player_instance: CharacterBody2D = null


func _ready() -> void:
	if combat_system_node.has_method("initialize"):
		combat_system_node.initialize(self, camera)

	_spawn_player()
	_spawn_test_enemies()
	EventBus.level_loaded.emit("demo_level")
	EventBus.player_died.connect(_on_player_died)
	EventBus.game_restarted.connect(_on_game_restarted)


func _process(_delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack"):
			GameManager.restart_game()


func _spawn_player() -> void:
	if not player_scene:
		push_error("Player scene not assigned!")
		return

	player_instance = player_scene.instantiate()
	player_instance.global_position = player_spawn.global_position if player_spawn else Vector2(100, 420)
	add_child(player_instance)
	player_instance.add_to_group("player")
	camera.set("follow_target", player_instance)

	var ui_scene: PackedScene = load("res://scenes/ui.tscn")
	var ui_instance: CanvasLayer = ui_scene.instantiate()
	add_child(ui_instance)


func _spawn_test_enemies() -> void:
	var bugs: PackedScene = load("res://scenes/enemy_bug.tscn")
	var guard: PackedScene = load("res://scenes/enemy_guard.tscn")
	var boss: PackedScene = load("res://scenes/enemy_boss.tscn")

	var e1: CharacterBody2D = bugs.instantiate()
	e1.global_position = Vector2(350, 440)
	enemy_container.add_child(e1)

	var e2: CharacterBody2D = bugs.instantiate()
	e2.global_position = Vector2(500, 440)
	enemy_container.add_child(e2)

	var e3: CharacterBody2D = bugs.instantiate()
	e3.global_position = Vector2(650, 440)
	enemy_container.add_child(e3)

	var g1: CharacterBody2D = guard.instantiate()
	g1.global_position = Vector2(900, 440)
	enemy_container.add_child(g1)

	var g2: CharacterBody2D = guard.instantiate()
	g2.global_position = Vector2(1300, 430)
	enemy_container.add_child(g2)

	var b1: CharacterBody2D = boss.instantiate()
	b1.global_position = Vector2(1700, 430)
	enemy_container.add_child(b1)


func _on_player_died() -> void:
	GameManager.set_state(GameManager.GameState.GAME_OVER)


func _on_game_restarted() -> void:
	get_tree().reload_current_scene()


func transition_to_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
