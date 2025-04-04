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
var continuous_direction: int = 1   # 连续移动方向: 1=向右, -1=向左

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

# 抽奖动画变量
var is_drawing: bool = false      # 是否正在抽奖中
var draw_speed: float = 20.0      # 初始抽奖速度
var draw_deceleration: float = 0.95  # 减速因子
var min_draw_speed: float = 0.5   # 最小抽奖速度
var draw_duration: float = 0.0    # 当前抽奖持续时间
var max_draw_duration: float = 3.0  # 最大抽奖持续时间
var selected_entry: EntryResource = null  # 选中的作品

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
	if is_drawing:
		# 处理抽奖动画
		_process_drawing_animation(delta)
	elif not enable_carousel or entry_nodes.is_empty() or is_transitioning:
		return
	else:
		# 更新轮播位置
		carousel_position += carousel_speed * delta * continuous_direction
		if carousel_position >= 1.0 or carousel_position <= -1.0:
			carousel_position = 0.0
			# 轮换一个作品
			_rotate_carousel_entries()
		
		# 应用轮播效果
		_apply_carousel_effect(delta)

## 处理抽奖动画
func _process_drawing_animation(delta: float) -> void:
	# 更新抽奖持续时间
	draw_duration += delta
	
	# 减速
	draw_speed *= draw_deceleration
	
	# 移动作品
	var scroll_amount = draw_speed * delta
	entries_scroll_container.scroll_horizontal += scroll_amount * 100
	
	# 如果速度足够慢或者已经达到最大持续时间，停止抽奖
	if draw_speed <= min_draw_speed or draw_duration >= max_draw_duration:
		_finish_drawing()

## 完成抽奖
func _finish_drawing() -> void:
	is_drawing = false
	draw_button.disabled = false
	
	# 确定中间位置的作品
	var center_pos = entries_scroll_container.size.x / 2
	var closest_entry = null
	var closest_distance = INF
	
	for item in entry_nodes:
		var item_center = item.global_position.x + (item.size.x * item.scale.x) / 2
		var distance = abs(item_center - (entries_scroll_container.global_position.x + center_pos))
		
		if distance < closest_distance:
			closest_distance = distance
			closest_entry = item
	
	# 获取选中作品的数据
	if closest_entry and closest_entry.entry:
		selected_entry = closest_entry.entry
		
		# 显示获奖弹窗
		_show_winner_dialog(selected_entry)
		
		# 更新当前获奖者标签
		current_winner_label.text = "恭喜 %s 获奖!" % selected_entry.title

## 显示获奖弹窗
func _show_winner_dialog(winner: EntryResource) -> void:
	var dialog = load("res://scenes/ui/winner_dialog.tscn").instantiate()
	add_child(dialog)
	dialog.set_winner(winner)
	dialog.confirmed.connect(_on_winner_dialog_confirmed)

## 获奖弹窗确认回调
func _on_winner_dialog_confirmed(winner: EntryResource) -> void:
	# 将获奖者添加到获奖者列表
	_add_winner_to_list(winner)
	
	# 通知RaffleManager
	var available_entries = RaffleManager.get_available_entries(devlog_filter_checkbox.button_pressed)
	for entry in available_entries:
		if entry.id == winner.id:
			RaffleManager.draw_winner_from_list([entry])
			break

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
	
	# 计算目标位置（根据方向移动一个项目的宽度）
	var item_width = ENTRY_WIDTH + entries_list.get_theme_constant("separation")
	for i in range(entry_nodes.size()):
		var new_pos = start_positions[i]
		new_pos.x -= item_width * continuous_direction  # 使用方向
		target_positions.append(new_pos)
	
	# 创建过渡动画
	carousel_tween = create_tween()
	carousel_tween.set_parallel(true)
	
	# 为每个项目添加动画
	for i in range(entry_nodes.size()):
		carousel_tween.tween_property(entry_nodes[i], "position", target_positions[i], 0.5).set_ease(Tween.EASE_IN_OUT)
	
	# 动画完成后重置位置并添加新项目
	carousel_tween.chain().tween_callback(func():
		# 根据方向移动条目
		if continuous_direction > 0:  # 向右移动
			# 移除最后一个作品并添加到开头
			var last_entry = visible_entries.pop_back()
			visible_entries.push_front(last_entry)
		else:  # 向左移动
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

## 更新UI
func update_ui() -> void:
	# 获取所有可用作品
	all_entries = DataManager.get_entries()
	
	# 应用过滤器
	var filtered_entries = []
	for entry in all_entries:
		if not devlog_filter_checkbox.button_pressed or entry.has_devlog:
			filtered_entries.append(entry)
	
	# 更新可见作品
	visible_entries = filtered_entries.duplicate()
	
	# 更新轮播项目
	_update_carousel_items()
	
	# 更新获奖者列表
	_update_winners_list()

## 更新轮播项目
func _update_carousel_items() -> void:
	# 清空当前项目
	for child in entries_list.get_children():
		child.queue_free()
	
	entry_nodes.clear()
	
	# 如果没有作品，直接返回
	if visible_entries.is_empty():
		return
	
	# 确保有足够的作品显示
	while visible_entries.size() < VISIBLE_ENTRIES:
		visible_entries.append_array(visible_entries.duplicate())
	
	# 创建可见的作品项目
	var start_index = 0
	var end_index = min(start_index + VISIBLE_ENTRIES, visible_entries.size())
	
	for i in range(start_index, end_index):
		var entry = visible_entries[i]
		var item = load("res://scenes/ui/entry_list_item.tscn").instantiate()
		entries_list.add_child(item)
		item.setup(entry)
		entry_nodes.append(item)

## 更新获奖者列表
func _update_winners_list() -> void:
	# 清空当前获奖者
	for child in winners_list.get_children():
		child.queue_free()
	
	# 获取获奖者列表
	var winners = RaffleManager.get_winners()
	
	# 创建获奖者项目
	for winner in winners:
		_add_winner_to_list(winner)

## 添加获奖者到列表
func _add_winner_to_list(winner: EntryResource) -> void:
	var item = load("res://scenes/ui/entry_list_item.tscn").instantiate()
	winners_list.add_child(item)
	item.setup(winner)
	
	# 添加动画效果
	item.scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2.ONE, 0.5)

## 开始抽奖按钮点击
func _on_draw_button_pressed() -> void:
	# 检查是否有可用作品
	var available_entries = RaffleManager.get_available_entries(devlog_filter_checkbox.button_pressed)
	if available_entries.is_empty():
		OS.alert("没有可用的参赛作品进行抽奖", "提示")
		return
	
	# 禁用抽奖按钮，防止重复点击
	draw_button.disabled = true
	
	# 开始抽奖动画
	_start_drawing_animation()

## 开始抽奖动画
func _start_drawing_animation() -> void:
	is_drawing = true
	draw_speed = 20.0
	draw_duration = 0.0
	
	# 确保有足够的作品显示
	update_ui()
	
	# 随机打乱可见作品
	visible_entries.shuffle()
	_update_carousel_items()

## 重置按钮点击
func _on_reset_button_pressed() -> void:
	# 重置RaffleManager
	RaffleManager.reset()
	
	# 重置UI
	current_winner_label.text = "等待抽取幸运儿..."
	update_ui()

## 开发日志过滤器切换
func _on_devlog_filter_toggled(button_pressed: bool) -> void:
	update_ui()

## 导出按钮点击
func _on_export_button_pressed() -> void:
	# 检查是否有获奖者
	if RaffleManager.get_winners().is_empty():
		OS.alert("没有获奖者可导出", "提示")
		return
	
	# 显示导出对话框
	export_dialog.popup_centered()

## 导出对话框确认
func _on_export_dialog_confirmed(path: String) -> void:
	# 使用DataManager导出获奖者
	var result: Dictionary = DataManager.export_winners(path)
	
	if result.get("success", false):
		OS.alert("导出成功: %s" % path, "成功")
	else:
		OS.alert("导出失败: %s" % result.get("message", "未知错误"), "错误")

## 获奖者抽取回调
func _on_winner_drawn(winner: EntryResource) -> void:
	# 更新UI
	update_ui()

## 抽奖重置回调
func _on_raffle_reset() -> void:
	# 更新UI
	update_ui()
