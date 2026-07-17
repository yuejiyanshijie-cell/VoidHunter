# event_bus.gd
# 全局事件总线 - 解耦各模块通信
# 所有重要的游戏事件都通过这里广播
extends Node

# =============================================================================
# 玩家事件
# =============================================================================
## 玩家受到伤害 (amount, source)
signal player_damaged(amount: float, source: Node2D)
## 玩家死亡
signal player_died()
## 玩家生命值变化 (current, max)
signal player_health_changed(current: float, max_hp: float)
## 玩家使用技能 (skill_id)
signal player_skill_used(skill_id: int)
## 技能冷却更新 (skill_id, remaining, total)
signal skill_cooldown_updated(skill_id: int, remaining: float, total: float)

# =============================================================================
# 战斗事件
# =============================================================================
## 敌人被击杀 (enemy, position)
signal enemy_killed(enemy: Node2D, position: Vector2)
## 伤害数字显示 (amount, position, is_critical)
signal damage_number_request(amount: float, position: Vector2, is_critical: bool)
## 命中特效触发 (position, type)
signal hit_effect_request(position: Vector2, type: StringName)

# =============================================================================
# 游戏流程事件
# =============================================================================
## 关卡加载
signal level_loaded(level_name: String)
## Boss战开始
signal boss_fight_started(boss: Node2D)
## Boss被击败
signal boss_defeated()
## 游戏暂停/恢复
signal game_paused(paused: bool)

# =============================================================================
# 摄像机事件
# =============================================================================
## 屏幕震动 (amplitude, duration)
signal screen_shake_request(amplitude: float, duration: float)
## 时间缩放 (scale, duration)
signal time_scale_request(scale: float, duration: float)

# =============================================================================
# 收集品事件
# =============================================================================
## 能量球收集 (total_count)
signal orb_collected(total_count: int)
## 游戏重启
signal game_restarted()
