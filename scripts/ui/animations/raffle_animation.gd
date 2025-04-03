extends Control
# CSGO风格抽奖动画

# 引用抽奖管理器
var raffle_manager

# 动画参数
var animation_duration = 4.0  # 动画总时长
var initial_speed = 3000  # 初始滚动速度
var final_speed = 20  # 最终滚动速度
var item_width = 180  # 每个项目的宽度
var item_spacing = 10  # 项目间距
var entries = []  # 所有参赛作品
var winner = null  # 获奖者
var prize = null  # 奖项
var is_animating = false  # 是否正在动画
var scroll_position = 0  # 当前滚动位置
var target_position = 0  # 目标滚动位置
var current_speed = 0  # 当前滚动速度
var animation_time = 0  # 当前动画时间

# 节点引用
@onready var items_container = %ItemsContainer
@onready var indicator = %Indicator
@onready var winner_info = %WinnerInfo

func _ready():
	raffle_manager = get_node("/root/RaffleManager")
	winner_info.text = ""

# 初始化抽奖动画
func initialize(prize_data):
	prize = prize_data
	entries = raffle_manager.entries.duplicate()
	
	# 显示奖项信息
	$VBoxContainer/PrizeInfo.text = "正在抽取：" + prize.name
	
	# 清空容器
	for child in items_container.get_children():
		child.queue_free()
	
	# 随机排序所有参赛作品
	entries.shuffle()
	
	# 创建足够多的项目填满滚动区域
	var viewport_width = get_viewport_rect().size.x
	var items_needed = int(viewport_width / float(item_width + item_spacing) * 5) + 10  # 5倍视口宽度
	
	# 先放一堆随机顺序的作品
	for i in range(items_needed):
		var entry_index = i % entries.size()
		add_entry_item(entries[entry_index])

# 添加一个参赛作品项目到容器
func add_entry_item(entry_data):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(item_width, 200)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	
	var vbox = VBoxContainer.new()
	
	# 创建图片显示
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(0, 120)
	# 设置纹理拉伸模式 (1=保持纵横比, 5=居中保持比例)
	texture_rect.expand_mode = 1
	texture_rect.stretch_mode = 5
	
	# 加载图片
	if entry_data.image and entry_data.image != "":
		var texture = load(entry_data.image)
		if texture:
			texture_rect.texture = texture
	
	# 创建标题和作者标签
	var title = Label.new()
	title.text = entry_data.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	
	var author = Label.new()
	author.text = entry_data.user
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
	author.add_theme_font_size_override("font_size", 12)
	
	# 组装UI
	vbox.add_child(texture_rect)
	vbox.add_child(title)
	vbox.add_child(author)
	margin.add_child(vbox)
	panel.add_child(margin)
	
	# 存储条目数据
	panel.set_meta("entry_data", entry_data)
	
	items_container.add_child(panel)
	return panel

# 开始抽奖动画
func start_animation(winner_data):
	if is_animating:
		return
	
	winner = winner_data
	is_animating = true
	animation_time = 0
	current_speed = initial_speed
	
	# 计算终点位置 - 将获奖者放在指示器中间
	var winner_item = null
	var items = items_container.get_children()
	
	# 在适当位置插入获奖者
	# 我们需要确保获奖者在视口中央稍微偏右的位置停下
	var center_position = get_viewport_rect().size.x / 2
	var target_position_offset = center_position + item_width * 4 + item_spacing * 4
	
	# 在现有的项目中，找到一个合适的位置插入获奖者
	var insert_index = int(target_position_offset / float(item_width + item_spacing))
	
	# 在指定位置添加获奖者
	if insert_index < items.size():
		items[insert_index].queue_free()
		winner_item = add_entry_item(winner)
	else:
		winner_item = add_entry_item(winner)
	
	# 计算目标滚动位置
	var winner_global_pos = winner_item.global_position.x
	var indicator_global_pos = indicator.global_position.x
	target_position = winner_global_pos - indicator_global_pos + item_width / 2
	
	# 显示动画
	show()

# 处理动画
func _process(delta):
	if not is_animating:
		return
	
	animation_time += delta
	var t = min(animation_time / animation_duration, 1.0)
	
	# 计算当前速度 - 使用缓动函数实现速度变化
	current_speed = initial_speed * (1 - ease(t, 4)) + final_speed * ease(t, 0.5)
	
	# 更新滚动位置
	scroll_position += current_speed * delta
	items_container.get_parent().scroll_horizontal = int(scroll_position)
	
	# 检查是否完成
	if t >= 1.0:
		is_animating = false
		on_animation_completed()

# 动画完成时调用
func on_animation_completed():
	# 高亮显示获奖者
	var items = items_container.get_children()
	for item in items:
		var entry_data = item.get_meta("entry_data", null)
		if entry_data == winner:
			item.add_theme_stylebox_override("panel", create_winner_style())
			break
	
	# 显示获奖信息
	winner_info.text = "恭喜 " + winner.user + " 获得 " + prize.name + "!"

# 创建获奖者高亮样式
func create_winner_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.8, 0.3)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.7, 1.0, 1.0)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

# 关闭按钮被按下
func _on_close_button_pressed():
	hide()
