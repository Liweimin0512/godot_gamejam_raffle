extends Control
# 游戏抽奖系统 - 主场景脚本 (MVP版本)

# 节点引用
@onready var entries_list: HBoxContainer = %EntriesList
@onready var winners_list: HBoxContainer = %WinnersList
@onready var current_winner_label: Label = %CurrentWinner
@onready var draw_button: Button = %DrawButton
@onready var reset_button: Button = %ResetButton
@onready var devlog_filter_checkbox: CheckBox = %DevlogFilter
@onready var export_button: Button = %ExportButton
@onready var export_dialog: FileDialog = %ExportDialog
@onready var entries_scroll_container: ScrollContainer = %EntriesContainer

# 常量
const CSV_PATH: String = "res://config/entries.csv"
const VISIBLE_ENTRIES: int = 7  # 同时显示的作品数量
const ENTRY_WIDTH: float = 200.0  # 每个作品的基础宽度

# 轮播效果变量
var carousel_position: float = 0.0  # 当前轮播位置
var carousel_speed: float = 0.2     # 轮播速度（降低以使动画更平滑）
var enable_carousel: bool = true    # 控制轮播激活状态
var carousel_tween: Tween           # 用于平滑过渡的Tween
var is_transitioning: bool = false  # 是否正在过渡中

# 立体效果变量
var center_scale: float = 1.2     # 中心项目缩放
var side_scale: float = 0.7       # 侧面项目缩放
var scale_transition: float = 3.0  # 缩放过渡速度（降低以使过渡更平滑）

# 特效变量
var hover_scale: float = 1.3      # 鼠标悬停时的缩放
var bounce_amplitude: float = 0.05 # 弹跳效果振幅
var bounce_speed: float = 3.0     # 弹跳效果速度
var rotation_max: float = 0.05    # 最大旋转角度
var glow_strength: float = 0.2    # 发光强度

# 轮播数据
var all_entries: Array = []       # 所有参赛作品
var visible_entries: Array = []   # 当前可见的作品
var entry_nodes: Array = []       # 当前显示的节点

## 节点准备就绪时调用
func _ready() -> void:
	# 连接信号
	draw_button.pressed.connect(_on_draw_button_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	devlog_filter_checkbox.toggled.connect(_on_devlog_filter_toggled)
	export_button.pressed.connect(_on_export_button_pressed)
	export_dialog.file_selected.connect(_on_export_dialog_confirmed)
	
	# 连接RaffleManager信号
	RaffleManager.winner_drawn.connect(_on_winner_drawn)
	RaffleManager.raffle_reset.connect(_on_raffle_reset)
	
	# 初始化UI
	current_winner_label.text = "等待抽取幸运儿..."
	
	# 使用DataManager加载数据
	var success: bool = DataManager.fetch_data("csv", {"path": CSV_PATH})
	if not success:
		printerr("无法通过DataManager启动数据加载")
		OS.alert("加载参赛作品失败", "错误")
	
	# 初始更新UI
	update_ui()
	
	# 创建轮播着色器材质
	_create_carousel_shader()

## 创建轮播着色器材质
func _create_carousel_shader() -> void:
	# 创建着色器材质
	var shader_material = ShaderMaterial.new()
	var shader_code = """
	shader_type canvas_item;
	
	uniform float glow_strength : hint_range(0.0, 1.0) = 0.2;
	uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
	
	void fragment() {
		vec4 current_color = texture(TEXTURE, UV);
		
		# 添加发光效果
		float edge = 0.05;
		float border = max(
			smoothstep(0.0, edge, UV.x) * smoothstep(1.0, 1.0 - edge, UV.x),
			smoothstep(0.0, edge, UV.y) * smoothstep(1.0, 1.0 - edge, UV.y)
		);
		
		vec4 glow = glow_color * glow_strength * border;
		COLOR = mix(current_color, glow, glow.a * border);
	}
	"""
	
	shader_material.shader = Shader.new()
	shader_material.shader.code = shader_code
	
	# 将材质应用到容器
	if entries_scroll_container:
		entries_scroll_container.material = shader_material

## 每帧处理轮播效果
func _process(delta: float) -> void:
	if not enable_carousel or entry_nodes.is_empty() or is_transitioning:
		return
	
	# 更新轮播位置
	carousel_position += carousel_speed * delta
	if carousel_position >= 1.0:
		carousel_position = 0.0
		# 轮换一个作品
		_rotate_carousel_entries()
	
	# 应用轮播效果
	_apply_carousel_effect(delta)

## 轮换轮播作品
func _rotate_carousel_entries() -> void:
	if all_entries.is_empty() or is_transitioning:
		return
	
	is_transitioning = true
	
	# 创建平滑过渡动画
	var start_positions = []
	var target_positions = []
	
	# 保存当前位置
	for item in entry_nodes:
		start_positions.append(item.position)
	
	# 计算目标位置（向左移动一个项目的宽度）
	var item_width = ENTRY_WIDTH + entries_list.get_theme_constant("separation")
	for i in range(entry_nodes.size()):
		var new_pos = start_positions[i]
		new_pos.x -= item_width
		target_positions.append(new_pos)
	
	# 创建过渡动画
	carousel_tween = create_tween()
	carousel_tween.set_parallel(true)
	
	# 为每个项目添加动画
	for i in range(entry_nodes.size()):
		carousel_tween.tween_property(entry_nodes[i], "position", target_positions[i], 0.5).set_ease(Tween.EASE_IN_OUT)
	
	# 动画完成后重置位置并添加新项目
	carousel_tween.chain().tween_callback(func():
		# 移除第一个作品并添加到末尾
		var first_entry = visible_entries.pop_front()
		visible_entries.push_back(first_entry)
		
		# 更新UI
		_update_carousel_items()
		
		is_transitioning = false
	)

## 应用轮播效果（中间大，两侧小，带动效）
func _apply_carousel_effect(delta: float) -> void:
	if entry_nodes.is_empty():
		return
	
	var center_index = entry_nodes.size() / 2
	var time_offset = Time.get_ticks_msec() / 1000.0
	var container_center = entries_scroll_container.size.x / 2
	
	# 为每个条目应用效果
	for i in range(entry_nodes.size()):
		var item = entry_nodes[i]
		if not is_instance_valid(item):
			continue
		
		# 计算到中心的距离（基于屏幕位置而非索引）
		var item_center = item.global_position.x + (item.size.x * item.scale.x) / 2
		var scroll_container_center = entries_scroll_container.global_position.x + container_center
		var pixel_distance = abs(item_center - scroll_container_center)
		var normalized_distance = clamp(pixel_distance / (container_center * 1.5), 0.0, 1.0)
		
		# 计算缩放
		var scale_factor = lerp(center_scale, side_scale, normalized_distance)
		
		# 添加弹跳效果（减小振幅使动画更平滑）
		var bounce = sin(time_offset * bounce_speed + i) * (bounce_amplitude * 0.8)
		scale_factor += bounce
		
		# 平滑过渡到新的缩放
		var current_scale = item.scale.x
		var new_scale = lerp(current_scale, scale_factor, scale_transition * delta)
		
		# 应用缩放
		item.scale = Vector2(new_scale, new_scale)
		
		# 应用旋转（减小角度使动画更平滑）
		var rotation_factor = sin(time_offset * 0.3 + i * 0.5) * (rotation_max * 0.8)
		item.rotation = rotation_factor
		
		# 应用透明度
		var alpha = lerp(1.0, 0.6, normalized_distance)
		item.modulate.a = alpha
		
		# Z索引（使中心项在顶部）
		item.z_index = 10 - int(normalized_distance * 10)

## 更新整个UI界面
func update_ui() -> void:
	_update_entries_carousel()
	_update_winners_list()
	_update_draw_button()

## 更新参赛作品轮播
func _update_entries_carousel() -> void:
	# 清空列表
	for child in entries_list.get_children():
		child.queue_free()
	
	# 重置数组
	entry_nodes.clear()
	all_entries.clear()
	visible_entries.clear()
	
	# 获取条目并应用过滤
	all_entries = DataManager.get_entries().duplicate()
	var show_devlog_only: bool = devlog_filter_checkbox.button_pressed
	
	# 应用过滤
	if show_devlog_only:
		var filtered_entries = []
		for entry in all_entries:
			if entry.has_devlog:
				filtered_entries.append(entry)
		all_entries = filtered_entries
	
	# 如果没有条目，返回
	if all_entries.is_empty():
		return
	
	# 随机打乱顺序以增加趣味性
	all_entries.shuffle()
	
	# 选择要显示的条目
	for i in range(min(VISIBLE_ENTRIES, all_entries.size())):
		visible_entries.append(all_entries[i])
	
	# 更新轮播项目
	_update_carousel_items()

## 更新轮播项目
func _update_carousel_items() -> void:
	# 清空当前项目
	for child in entries_list.get_children():
		child.queue_free()
	
	entry_nodes.clear()
	
	# 添加条目到UI
	var entry_item_scene: PackedScene = load("res://scenes/ui/entry_list_item.tscn")
	
	for entry in visible_entries:
		var item = entry_item_scene.instantiate()
		entries_list.add_child(item)
		entry_nodes.append(item)
		
		# 设置条目数据
		if item.has_method("setup"):
			item.setup(entry)
		else:
			printerr("entry_list_item.tscn 缺少 setup 方法")
		
		# 设置基础属性
		item.custom_minimum_size = Vector2(ENTRY_WIDTH, item.custom_minimum_size.y)
		item.pivot_offset = Vector2(ENTRY_WIDTH/2, item.custom_minimum_size.y/2)
		
		# 添加鼠标悬停效果
		_add_hover_effects(item)
	
	# 立即应用一次效果
	_apply_carousel_effect(0.1)

## 添加鼠标悬停效果
func _add_hover_effects(item: Control) -> void:
	# 确保项目可以接收鼠标事件
	item.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# 连接鼠标信号
	item.mouse_entered.connect(func(): _on_item_mouse_entered(item))
	item.mouse_exited.connect(func(): _on_item_mouse_exited(item))

## 鼠标进入项目
func _on_item_mouse_entered(item: Control) -> void:
	# 创建缩放动画
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(hover_scale, hover_scale), 0.2).set_ease(Tween.EASE_OUT)
	
	# 添加发光效果
	var panel = item as PanelContainer
	if panel:
		var style_box = panel.get_theme_stylebox("panel").duplicate()
		if style_box is StyleBoxFlat:
			style_box.shadow_size = 15
			style_box.shadow_color = Color(1, 1, 1, 0.3)
			panel.add_theme_stylebox_override("panel", style_box)

## 鼠标离开项目
func _on_item_mouse_exited(item: Control) -> void:
	# 恢复原始状态（轮播效果会自动处理）
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_IN)
	
	# 移除发光效果
	var panel = item as PanelContainer
	if panel:
		panel.remove_theme_stylebox_override("panel")

## 更新获奖者列表
func _update_winners_list() -> void:
	# 清空列表
	for child in winners_list.get_children():
		child.queue_free()
	
	# 获取获奖者
	var current_winners: Array = RaffleManager.get_winners()
	if current_winners.is_empty():
		return
	
	# 添加标题
	var title_label: Label = Label.new()
	title_label.text = "获奖名单:"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winners_list.add_child(title_label)
	
	# 添加获奖者到列表
	var entry_item_scene: PackedScene = load("res://scenes/ui/entry_list_item.tscn")
	for winner in current_winners:
		var item = entry_item_scene.instantiate()
		winners_list.add_child(item)
		
		# 设置获奖者数据
		if item.has_method("setup"):
			item.setup(winner)
		else:
			printerr("entry_list_item.tscn 缺少 setup 方法")
		
		# 设置静态样式（无动画）
		item.scale = Vector2(1, 1)
		item.rotation = 0
		item.modulate.a = 1
		item.z_index = 0

## 更新抽奖按钮状态
func _update_draw_button() -> void:
	# 获取可用条目数量
	var respect_filter: bool = devlog_filter_checkbox.button_pressed
	var available_count: int = RaffleManager.get_available_entries(respect_filter).size()
	
	# 如果没有可用条目，禁用抽奖按钮
	draw_button.disabled = available_count <= 0

## 当获奖者被抽出时调用
func _on_winner_drawn(winner) -> void:
	# 更新当前获奖者显示
	current_winner_label.text = "当前幸运儿: %s (%s)" % [winner.title, winner.author]
	
	# 更新UI
	update_ui()
	
	# 短暂延迟后恢复轮播
	await get_tree().create_timer(0.5).timeout
	enable_carousel = true

## 当抽奖重置时调用
func _on_raffle_reset() -> void:
	current_winner_label.text = "等待抽取幸运儿..."
	update_ui()

## 抽奖按钮处理
func _on_draw_button_pressed() -> void:
	# 暂停轮播
	enable_carousel = false
	current_winner_label.text = "正在抽取中..."
	
	# 获取可用条目
	var respect_filter: bool = devlog_filter_checkbox.button_pressed
	var available_entries: Array = RaffleManager.get_available_entries(respect_filter)
	
	if available_entries.is_empty():
		current_winner_label.text = "没有可抽奖的作品"
		enable_carousel = true
		return
	
	# 执行抽奖
	var winner = RaffleManager.draw_winner_from_list(available_entries)
	if not winner:
		printerr("抽奖失败")
		current_winner_label.text = "抽奖失败"
		enable_carousel = true

## 重置按钮处理
func _on_reset_button_pressed() -> void:
	RaffleManager.reset()
	# UI更新由raffle_reset信号触发

## 过滤器切换处理
func _on_devlog_filter_toggled(_button_pressed: bool) -> void:
	update_ui()

## 导出按钮处理
func _on_export_button_pressed() -> void:
	export_dialog.popup_centered()

## 导出对话框确认处理
func _on_export_dialog_confirmed(path: String) -> void:
	# 使用DataManager导出获奖者
	var result: Dictionary = DataManager.export_winners(path)
	
	if result.get("success", false):
		OS.alert("导出成功！\n已保存到: %s" % path, "导出完成")
	else:
		var error_message: String = result.get("message", "未知错误")
		OS.alert("导出文件失败！\n错误: %s" % error_message, "导出错误")
