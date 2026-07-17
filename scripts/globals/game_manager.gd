# game_manager.gd
# 游戏管理器 - 全局单例，管理游戏状态与场景切换
extends Node

# =============================================================================
# 游戏状态枚举
# =============================================================================
enum GameState {
	MAIN_MENU,     # 主菜单
	PLAYING,       # 游戏中
	PAUSED,        # 暂停
	GAME_OVER,     # 游戏结束
	BOSS_FIGHT,    # Boss战
	VICTORY        # 胜利
}

# =============================================================================
# 当前状态
# =============================================================================
var current_state: GameState = GameState.MAIN_MENU
var player_health: float = GameConstants.PLAYER_MAX_HEALTH
var player_max_health: float = GameConstants.PLAYER_MAX_HEALTH

# =============================================================================
# 技能冷却计时器
# =============================================================================
var skill_cooldowns: Dictionary = {
	1: {"remaining": 0.0, "total": GameConstants.SKILL1_COOLDOWN},
	2: {"remaining": 0.0, "total": GameConstants.SKILL2_COOLDOWN}
}


# =============================================================================
# 生命周期
# =============================================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时也运行


func _process(delta: float) -> void:
	# 更新技能冷却
	if current_state == GameState.PLAYING or current_state == GameState.BOSS_FIGHT:
		_update_cooldowns(delta)


# =============================================================================
# 状态管理
# =============================================================================
func set_state(new_state: GameState) -> void:
	current_state = new_state


func is_playing() -> bool:
	return current_state == GameState.PLAYING or current_state == GameState.BOSS_FIGHT


# =============================================================================
# 玩家生命值
# =============================================================================
func damage_player(amount: float, source: Node2D = null) -> void:
	player_health = max(0.0, player_health - amount)
	EventBus.player_health_changed.emit(player_health, player_max_health)
	EventBus.player_damaged.emit(amount, source)

	if player_health <= 0:
		EventBus.player_died.emit()


func heal_player(amount: float) -> void:
	player_health = min(player_max_health, player_health + amount)
	EventBus.player_health_changed.emit(player_health, player_max_health)


# =============================================================================
# 技能冷却
# =============================================================================
func use_skill(skill_id: int) -> bool:
	if skill_cooldowns[skill_id]["remaining"] > 0:
		return false
	skill_cooldowns[skill_id]["remaining"] = skill_cooldowns[skill_id]["total"]
	EventBus.player_skill_used.emit(skill_id)
	return true


func _update_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns:
		var cd = skill_cooldowns[skill_id]
		if cd["remaining"] > 0:
			cd["remaining"] = max(0.0, cd["remaining"] - delta)
			EventBus.skill_cooldown_updated.emit(skill_id, cd["remaining"], cd["total"])
