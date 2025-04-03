extends PanelContainer
class_name EntryListItem

## 参赛作品列表项UI组件
## 用于显示单个参赛作品的信息，包括标题、作者、权重和开发日志状态

# 节点引用
@onready var title_label: Label = %Title
@onready var author_label: Label = %Author
@onready var weight_spinbox: SpinBox = %Weight
@onready var game_image: TextureRect = %GameImage
@onready var devlog_icon: TextureRect = %DevlogIcon
@onready var devlog_label: Label = %DevlogLabel

# 条目数据
var entry: EntryResource = null

## 设置条目数据
## [param data] - 参赛作品资源对象
func setup(data: EntryResource) -> void:
	entry = data
	update_display()
	
	# 连接信号（如果尚未连接）
	if not weight_spinbox.value_changed.is_connected(_on_weight_value_changed):
		weight_spinbox.value_changed.connect(_on_weight_value_changed)

## 更新UI显示
func update_display() -> void:
	if not entry:
		return
		
	# 更新基本信息
	title_label.text = entry.title
	author_label.text = entry.author
	weight_spinbox.value = entry.weight
	
	# 更新游戏图片
	_update_game_image()
	
	# 更新开发日志状态
	_update_devlog_status()

## 更新游戏图片
func _update_game_image() -> void:
	# 重置图片
	game_image.texture = null
	
	# 检查并加载图片
	if entry.image:
		game_image.texture = entry.image


## 更新开发日志状态显示
func _update_devlog_status() -> void:
	var has_devlog: bool = entry.has_devlog
	
	# 更新开发日志图标和标签可见性
	devlog_icon.visible = has_devlog
	devlog_label.visible = has_devlog
	
	if has_devlog:
		devlog_label.text = "有开发日志"

## 权重值变化时的回调
## [param value] - 新的权重值
func _on_weight_value_changed(value: float) -> void:
	if entry:
		entry.weight = value
		# 如果需要，可以在这里添加代码通知其他系统权重已更改
