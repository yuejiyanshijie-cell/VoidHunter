# game_constants.gd
# 全局游戏常量 - Autoload单例，所有模块共享的数据源头
extends Node

# =============================================================================
# 显示设置
# =============================================================================
const GAME_WIDTH := 960
const GAME_HEIGHT := 540
const PIXEL_SCALE := 2.0

# =============================================================================
# 物理设置
# =============================================================================
const GRAVITY := 1200.0
const TERMINAL_VELOCITY := 600.0

# =============================================================================
# 玩家属性
# =============================================================================
const PLAYER_SPEED := 200.0
const PLAYER_JUMP_VELOCITY := -420.0
const PLAYER_DOUBLE_JUMP_VELOCITY := -350.0
const PLAYER_DASH_SPEED := 600.0
const PLAYER_DASH_DURATION := 0.18
const PLAYER_DASH_COOLDOWN := 0.6
const PLAYER_WALL_SLIDE_SPEED := 80.0
const PLAYER_WALL_JUMP_H := 300.0
const PLAYER_WALL_JUMP_V := -400.0
const PLAYER_MAX_HEALTH := 100.0

# =============================================================================
# 战斗属性
# =============================================================================
const ATTACK_DAMAGE_LIGHT := 15.0
const ATTACK_DAMAGE_HEAVY := 35.0
const ATTACK_DAMAGE_DOWNSTRIKE := 18.0
const DODGE_DURATION := 0.3
const DODGE_COOLDOWN := 0.5
const DODGE_INVINCIBLE_TIME := 0.2

# =============================================================================
# 技能属性
# =============================================================================
const SKILL1_DAMAGE := 30.0
const SKILL1_KNOCKBACK := 400.0
const SKILL1_COOLDOWN := 3.0
const SKILL1_RANGE := 150.0

const SKILL2_DAMAGE := 45.0
const SKILL2_RANGE := 120.0
const SKILL2_COOLDOWN := 8.0
const SKILL2_DURATION := 2.0

# =============================================================================
# 敌人属性
# =============================================================================
const ENEMY_BUG_SPEED := 120.0
const ENEMY_BUG_HEALTH := 20.0
const ENEMY_BUG_DAMAGE := 10.0

const ENEMY_GUARD_SPEED := 60.0
const ENEMY_GUARD_HEALTH := 45.0
const ENEMY_GUARD_DAMAGE := 10.0

const ENEMY_BOSS_SPEED := 150.0
const ENEMY_BOSS_HEALTH := 300.0
const ENEMY_BOSS_DAMAGE := 18.0

# =============================================================================
# 输入缓存
# =============================================================================
const JUMP_BUFFER_TIME := 0.1
const DASH_BUFFER_TIME := 0.1
const COYOTE_TIME := 0.08
