# ui_manager.gd - UI管理器
extends CanvasLayer

# UI 元素（延迟查找，避免路径错误崩溃）
var health_bar: ProgressBar
var health_label: Label
var skill1_label: Label
var skill2_label: Label
var skill1_icon: TextureRect
var skill2_icon: TextureRect
var game_over_label: Label


func _ready() -> void:
	_find_ui_elements()

	# 初始化显示
	if health_bar:
		health_bar.max_value = GameConstants.PLAYER_MAX_HEALTH
		health_bar.value = GameConstants.PLAYER_MAX_HEALTH
	if health_label:
		health_label.text = str(int(GameConstants.PLAYER_MAX_HEALTH))

	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.skill_cooldown_updated.connect(_on_cooldown_updated)
	EventBus.player_died.connect(_on_player_died)


func _find_ui_elements() -> void:
	# 安全查找：通过递归搜索
	var h_box: HBoxContainer = _find_child_of_type(self, "HBoxContainer")
	if not h_box:
		push_warning("[UI] HBoxContainer not found — UI disabled")
		return

	var v_box: VBoxContainer = _find_child_of_type(h_box, "VBoxContainer")
	if v_box:
		health_bar = _find_child_of_type(v_box, "ProgressBar")
		health_label = _find_child_of_type(v_box, "Label")

	var skills_vbox: VBoxContainer = null
	for child in h_box.get_children():
		if child is VBoxContainer and child != v_box:
			skills_vbox = child
			break

	if skills_vbox:
		var icons: Array = []
		var labels: Array = []
		for child in skills_vbox.get_children():
			for sub in child.get_children():
				if sub is TextureRect and icons.size() < 2:
					icons.append(sub)
				if sub is Label and labels.size() < 2:
					labels.append(sub)

		if icons.size() >= 2:
			skill1_icon = icons[0]
			skill2_icon = icons[1]
		if labels.size() >= 2:
			skill1_label = labels[0]
			skill2_label = labels[1]


func _find_child_of_type(parent: Node, type_name: String) -> Variant:
	for child in parent.get_children():
		if child.get_class() == type_name:
			return child
		var found: Variant = _find_child_of_type(child, type_name)
		if found:
			return found
	return null


func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar:
		health_bar.value = current
		health_bar.max_value = max_hp
		health_bar.modulate = Color.RED if current / max_hp < 0.3 else Color.WHITE
	if health_label:
		health_label.text = str(int(current))


func _on_cooldown_updated(skill_id: int, remaining: float, _total: float) -> void:
	var label: Label = skill1_label if skill_id == 1 else skill2_label
	var icon: TextureRect = skill1_icon if skill_id == 1 else skill2_icon

	if label:
		label.text = str(ceil(remaining)) if remaining > 0 else ""
	if icon:
		icon.modulate = Color(0.5, 0.5, 0.5, 1) if remaining > 0 else Color.WHITE


func _on_player_died() -> void:
	if game_over_label:
		return
	game_over_label = Label.new()
	game_over_label.text = "YOU DIED"
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_color", Color.RED)
	game_over_label.anchors_preset = Control.PRESET_CENTER
	add_child(game_over_label)
	print("[UI] Game Over displayed")
