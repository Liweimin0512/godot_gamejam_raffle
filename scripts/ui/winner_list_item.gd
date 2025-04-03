extends PanelContainer
# 获奖者列表项

# 节点引用
@onready var title_label = $MarginContainer/HBoxContainer/WinnerInfo/Title
@onready var author_label = $MarginContainer/HBoxContainer/WinnerInfo/Author

# 获奖者数据
var winner_data = null

# 设置获奖者数据
func setup(data):
	winner_data = data
	update_display()

# 更新显示
func update_display():
	if winner_data:
		title_label.text = winner_data.title
		author_label.text = winner_data.author if winner_data.has("author") else ""
