extends PanelContainer
# 参赛作品列表项

# 引用节点
@onready var title_label = %Title
@onready var author_label = %Author
@onready var weight_spinbox = %Weight
@onready var game_image = %GameImage
@onready var devlog_icon = %DevlogIcon
@onready var devlog_label = %DevlogLabel

# 条目数据
var entry_data = null

# 设置条目数据
func setup(data):
	entry_data = data
	update_display()

# 更新显示
func update_display():
	if entry_data:
		title_label.text = entry_data.title
		author_label.text = entry_data.author if entry_data.has("author") else ""
		weight_spinbox.value = entry_data.weight
		
		# 设置游戏图片
		if entry_data.has("image") and entry_data.image != "":
			var texture = load(entry_data.image)
			if texture:
				game_image.texture = texture
		
		# 显示开发日志状态
		if entry_data.has_devlog:
			devlog_icon.visible = true
			devlog_label.visible = true
			devlog_label.text = "有开发日志"
		else:
			devlog_icon.visible = false
			devlog_label.visible = false

# 权重值变化
func _on_weight_value_changed(value):
	if entry_data:
		entry_data.weight = value
