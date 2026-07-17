# level_builder.gd - 代码生成关卡地图
extends Node2D

const GROUND_Y: float = 480.0
const GROUND_HEIGHT: float = 60.0
const GROUND_WIDTH: float = 9600.0
const CAVE_Y: float = 700.0
const GAP_START: float = 3800.0
const GAP_END: float = 4600.0

const WALL_COLOR: Color = Color(0.12, 0.12, 0.20)
const FLOOR_COLOR: Color = Color(0.2, 0.2, 0.28)
const PLATFORM_COLOR: Color = Color(0.16, 0.16, 0.4)
const BG_COLOR: Color = Color(0.03, 0.03, 0.06)

# [x, y, width] — 精心设计的跑酷路线
const PLATFORMS: Array[Array] = [
	# --- 上层路径 (高空) ---
	[300, 360, 160],
	[520, 300, 140],
	[700, 360, 120],
	[880, 280, 180],
	[1100, 340, 130],
	[1300, 260, 160],
	[1480, 320, 140],
	[600, 220, 100],
	[1000, 190, 110],
	[1400, 180, 120],
	[1700, 240, 140],
	[1900, 300, 130],
	[2100, 350, 150],
	[2300, 260, 120],
	[2500, 320, 140],
	# --- 下层洞穴 (CAVE_Y 附近) ---
	[280, 680, 130],
	[460, 650, 140],
	[660, 690, 140],
	[880, 660, 160],
	[1120, 680, 130],
	[1360, 640, 150],
	[1600, 670, 120],
	[1860, 700, 140],
	# --- 中层连接 ---
	[320, 440, 120],
	[560, 480, 110],
	[920, 430, 130],
	[1200, 420, 120],
	[1520, 460, 140],
	# --- 扩展区域上层 ---
	[2800, 280, 130],
	[3100, 340, 120],
	[3400, 220, 140],
	[3700, 180, 120],
	[5000, 300, 140],
	[5300, 200, 130],
	[5600, 340, 150],
	[5900, 260, 120],
	[6200, 320, 140],
	[6600, 200, 130],
	[7000, 360, 150],
	# --- 扩展区域下层 ---
	[4800, 680, 130],
	[5100, 650, 140],
	[5400, 690, 150],
	[5800, 660, 120],
	[6300, 680, 140],
	[6800, 640, 130],
	[7200, 700, 150],
]


func _ready() -> void:
	_create_background()
	_create_ground()
	_create_platforms()
	_create_walls()
	_create_decorations()
	_create_atmosphere()


# ============================================================
# 背景
# ============================================================
func _create_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(GROUND_WIDTH, 600)
	bg.position = Vector2.ZERO
	bg.z_index = -20
	add_child(bg)

	# 星空粒子
	for i: int in range(80):
		var star: ColorRect = ColorRect.new()
		var sx: float = randf_range(0, GROUND_WIDTH)
		var sy: float = randf_range(0, GROUND_Y)
		var ss: float = randf_range(1, 3)
		star.size = Vector2(ss, ss)
		star.position = Vector2(sx, sy)
		star.color = Color(0.5, 0.5, 1, randf_range(0.3, 0.8))
		star.z_index = -19
		add_child(star)

	# 巨大外星结构剪影
	for i: int in range(5):
		var struct: ColorRect = ColorRect.new()
		var sh: float = randf_range(100, 250)
		var sw: float = randf_range(3, 8)
		struct.size = Vector2(sw, sh)
		struct.position = Vector2(150 + i * 400, GROUND_Y - sh)
		struct.color = Color(0.06, 0.06, 0.15, 0.8)
		struct.z_index = -18
		add_child(struct)


# ============================================================
# 地面
# ============================================================
func _create_ground() -> void:
	# 地面被缺口分为左右两段
	var segments: Array[Dictionary] = [
		{"start": 0, "end": GAP_START},
		{"start": GAP_END, "end": GROUND_WIDTH},
	]

	for seg: Dictionary in segments:
		var seg_w: float = seg["end"] - seg["start"]
		var seg_cx: float = seg["start"] + seg_w / 2

		var ground: StaticBody2D = StaticBody2D.new()
		ground.name = "Ground"
		ground.position = Vector2(seg_cx, GROUND_Y + GROUND_HEIGHT / 2)
		ground.collision_layer = 1
		ground.collision_mask = 0

		var coll: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(seg_w, GROUND_HEIGHT)
		coll.shape = rect
		ground.add_child(coll)

		var vis: ColorRect = ColorRect.new()
		vis.color = FLOOR_COLOR
		vis.size = Vector2(seg_w, GROUND_HEIGHT)
		vis.position = Vector2(-seg_w / 2, -GROUND_HEIGHT / 2)
		ground.add_child(vis)

		var glow: ColorRect = ColorRect.new()
		glow.color = Color(0.2, 0.15, 0.5, 0.4)
		glow.size = Vector2(seg_w, 2)
		glow.position = Vector2(-seg_w / 2, -GROUND_HEIGHT / 2)
		ground.add_child(glow)

		add_child(ground)

	# 缺口尖刺
	var spike_count: int = int((GAP_END - GAP_START) / 32)
	for i: int in range(spike_count):
		var spike: ColorRect = ColorRect.new()
		var sx: float = GAP_START + i * 32 + 16
		spike.size = Vector2(20, 14)
		spike.position = Vector2(sx - 10, GROUND_Y - 6)
		spike.color = Color(0.5, 0.05, 0.05, 1)
		spike.z_index = 1
		add_child(spike)

		# 尖刺碰撞
		var spike_body: StaticBody2D = StaticBody2D.new()
		spike_body.position = Vector2(sx, GROUND_Y)
		spike_body.collision_layer = 0
		spike_body.collision_mask = 0
		var spike_coll: CollisionShape2D = CollisionShape2D.new()
		var spike_shape: RectangleShape2D = RectangleShape2D.new()
		spike_shape.size = Vector2(16, 12)
		spike_coll.shape = spike_shape
		spike_body.add_child(spike_coll)
		spike_body.set_meta("is_spike", true)
		add_child(spike_body)


# ============================================================
# 悬浮平台
# ============================================================
func _create_platforms() -> void:
	for arr: Array in PLATFORMS:
		var x: float = float(arr[0])
		var y: float = float(arr[1])
		var w: float = float(arr[2])
		_create_platform(x, y, w)


func _create_platform(x: float, y: float, w: float) -> void:
	var p: StaticBody2D = StaticBody2D.new()
	p.name = "Platform"
	p.position = Vector2(x + w / 2, y)
	p.collision_layer = 1
	p.collision_mask = 0

	var coll: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(w, 8)
	coll.shape = rect
	p.add_child(coll)

	var vis: ColorRect = ColorRect.new()
	vis.color = PLATFORM_COLOR
	vis.size = Vector2(w, 8)
	vis.position = Vector2(-w / 2, -4)
	p.add_child(vis)

	# 能量发光条
	var stripe: ColorRect = ColorRect.new()
	stripe.color = Color(0.2, 0.15, 0.6, 0.6)
	stripe.size = Vector2(w - 8, 2)
	stripe.position = Vector2(-w / 2 + 4, -3)
	p.add_child(stripe)

	add_child(p)


# ============================================================
# 墙壁
# ============================================================
func _create_walls() -> void:
	_create_wall(0, 240, 10, 480)
	_create_wall(GROUND_WIDTH - 10, 240, 10, 480)


func _create_wall(x: float, y: float, w: float, h: float) -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.name = "Wall"
	wall.position = Vector2(x + w / 2, y)
	wall.collision_layer = 1
	wall.collision_mask = 0

	var coll: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(w, h)
	coll.shape = rect
	wall.add_child(coll)

	var vis: ColorRect = ColorRect.new()
	vis.color = WALL_COLOR
	vis.size = Vector2(w, h)
	vis.position = Vector2(-w / 2, -h / 2)
	wall.add_child(vis)

	add_child(wall)


# ============================================================
# 装饰
# ============================================================
func _create_decorations() -> void:
	# 外星遗迹石碑
	for i: int in range(8):
		_create_monolith(280 + i * 180, GROUND_Y - 48)

	# 悬浮能量碎片
	for i: int in range(6):
		var shard: ColorRect = ColorRect.new()
		shard.size = Vector2(4, 4)
		shard.position = Vector2(400 + i * 250, randf_range(200, 350))
		shard.color = Color(0.3, 0.2, 1, 0.6)
		shard.z_index = -5
		add_child(shard)


func _create_monolith(x: float, y: float) -> void:
	var mono: ColorRect = ColorRect.new()
	mono.size = Vector2(10, 48)
	mono.position = Vector2(x - 5, y)
	mono.color = Color(0.1, 0.1, 0.18, 0.9)
	mono.z_index = -5
	add_child(mono)

	# 能量符文
	var rune: ColorRect = ColorRect.new()
	rune.size = Vector2(4, 6)
	rune.position = Vector2(x - 2, y + 10)
	rune.color = Color(0.3, 0.2, 0.8, 0.7)
	mono.add_child(rune)


# ============================================================
# 大气效果
# ============================================================
func _create_atmosphere() -> void:
	# 环境光雾（顶部渐暗）
	var fog: ColorRect = ColorRect.new()
	fog.size = Vector2(GROUND_WIDTH, 200)
	fog.position = Vector2(0, 0)
	fog.color = Color(0.02, 0.01, 0.04, 0.3)
	fog.z_index = -10
	add_child(fog)

	# 地面附近的雾气
	var mist: ColorRect = ColorRect.new()
	mist.size = Vector2(GROUND_WIDTH, 30)
	mist.position = Vector2(0, GROUND_Y - 20)
	mist.color = Color(0.03, 0.02, 0.08, 0.3)
	mist.z_index = -2
	add_child(mist)

	# 掉落死亡区域
	var death_zone: Area2D = Area2D.new()
	death_zone.name = "DeathZone"
	var dz_coll: CollisionShape2D = CollisionShape2D.new()
	var dz_shape: RectangleShape2D = RectangleShape2D.new()
	dz_shape.size = Vector2(GROUND_WIDTH, 80)
	dz_coll.shape = dz_shape
	death_zone.add_child(dz_coll)
	death_zone.position = Vector2(GROUND_WIDTH / 2, GROUND_Y + GROUND_HEIGHT + 40)
	death_zone.set_meta("death_zone", true)
	add_child(death_zone)

	# 收集品（能量球）
	var orb_positions: Array[Vector2] = [
		Vector2(450, 420),
		Vector2(750, 340),
		Vector2(1100, 320),
		Vector2(1600, 240),
		Vector2(2100, 330),
		Vector2(2800, 260),
		Vector2(3400, 200),
		Vector2(5100, 280),
		Vector2(6000, 240),
		Vector2(7000, 340),
	]
	for pos: Vector2 in orb_positions:
		_create_orb(pos)

func _create_orb(pos: Vector2) -> void:
	var orb: Area2D = Area2D.new()
	orb.name = "EnergyOrb"
	orb.position = pos
	orb.set_meta("is_orb", true)

	var coll: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 6
	coll.shape = shape
	orb.add_child(coll)

	var vis: ColorRect = ColorRect.new()
	vis.size = Vector2(8, 8)
	vis.position = Vector2(-4, -4)
	vis.color = Color(0.3, 0.6, 1, 0.9)
	vis.z_index = 2
	orb.add_child(vis)

	# 发光光晕
	var glow: ColorRect = ColorRect.new()
	glow.size = Vector2(14, 14)
	glow.position = Vector2(-7, -7)
	glow.color = Color(0.2, 0.4, 1, 0.25)
	glow.z_index = 1
	orb.add_child(glow)

	# 呼吸动画
	var t: Tween = create_tween().set_loops()
	t.tween_property(vis, "modulate:a", 0.5, 0.8)
	t.tween_property(vis, "modulate:a", 0.9, 0.8)
	var t2: Tween = create_tween().set_loops()
	t2.tween_property(glow, "size", Vector2(18, 18), 1.0)
	t2.tween_property(glow, "size", Vector2(14, 14), 1.0)

	add_child(orb)
