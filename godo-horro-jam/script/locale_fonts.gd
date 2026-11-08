extends Node
# Autoload: LocaleFonts. Для русского языка подставляет шрифты с кириллицей:
# меню и интерфейс: BlankSpotsRegular, надписи Label3D на стенах: Ustroke-Regular

const MENU_FONT_PATH := "res://title/Sjz.otf"
const WALL_FONT_PATH := "res://title/Ustroke-Regular.ttf"
const SKIP_GROUP := "keep_font"   # узлы из этой группы шрифт не меняют (например, название игры)
const DEBUG := true               # печатает в Вывод, что сделал скрипт (потом поставь false)

var _menu_font: Font
var _wall_font: Font
var _patched_ui := 0
var _patched_3d := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_apply)                   # каждый новый узел проверяется сам
	_apply_to_tree.call_deferred(get_tree().root)           # узлы, которые появились раньше

	if DEBUG:
		print("LocaleFonts: запущен. Шрифт меню найден: ", _get_menu_font() != null,
			", шрифт стен найден: ", _get_wall_font() != null)
		_print_font_support(_get_menu_font())
		_print_font_support(_get_wall_font())
		get_tree().create_timer(2.0).timeout.connect(_print_report)

# Проверяет, есть ли в файле шрифта кириллица, латиница и цифры
func _print_font_support(f: Font) -> void:
	if f == null:
		return
	print("Шрифт ", f.resource_path,
		": Ж = ", f.has_char(0x0416),
		", ж = ", f.has_char(0x0436),
		", латинская A = ", f.has_char(0x0041),
		", цифра 1 = ", f.has_char(0x0031))

# Через 2 секунды после запуска: сколько надписей получили новый шрифт
func _print_report() -> void:
	print("LocaleFonts: язык = ", TranslationServer.get_locale(),
		", заменено надписей интерфейса: ", _patched_ui,
		", Label3D: ", _patched_3d)

func _apply_to_tree(node: Node) -> void:
	_apply(node)
	for child in node.get_children():
		_apply_to_tree(child)

func _apply(node: Node) -> void:
	if not (node is Label3D or node is Label or node is Button):
		return
	if not TranslationServer.get_locale().begins_with("ru"):
		return   # на других языках шрифты остаются прежними
	if node.is_in_group(SKIP_GROUP):
		return

	if node is Label3D:
		var wall := _get_wall_font()
		if wall:
			(node as Label3D).font = wall
			_patched_3d += 1
		return

	var menu := _get_menu_font()
	if menu == null:
		return
	(node as Control).add_theme_font_override("font", menu)

	# У Label может быть LabelSettings со своим шрифтом: он важнее обычных настроек
	if node is Label:
		var label := node as Label
		if label.label_settings != null:
			var settings := label.label_settings.duplicate() as LabelSettings
			settings.font = menu
			label.label_settings = settings
	_patched_ui += 1

func _get_menu_font() -> Font:
	if _menu_font == null:
		if ResourceLoader.exists(MENU_FONT_PATH):
			_menu_font = load(MENU_FONT_PATH) as Font
		else:
			push_warning("LocaleFonts: нет файла шрифта меню '%s'" % MENU_FONT_PATH)
	return _menu_font

func _get_wall_font() -> Font:
	if _wall_font == null:
		if ResourceLoader.exists(WALL_FONT_PATH):
			_wall_font = load(WALL_FONT_PATH) as Font
		else:
			push_warning("LocaleFonts: нет файла шрифта стен '%s'" % WALL_FONT_PATH)
	return _wall_font
