extends Node3D
class_name MenuMonster

@export var anim_player: AnimationPlayer       # если пусто, найдётся внутри модели сам
@export var idle_animation := "Idle"
@export var aggressive_animation := "aggressive"
@export var waiting_animation := "waiting"
@export var blend_time := 0.3                  # плавность перехода между анимациями, сек
@export var animation_speed := 1.0             # общая скорость анимаций (меньше 1 = спокойнее)

# Сколько раз подряд играет Idle между активными анимациями (случайно от min до max)
@export var idle_repeats_min := 2
@export var idle_repeats_max := 4

# Шанс, что активная анимация повторится ещё раз подряд (0 = строго по очереди)
@export_range(0.0, 1.0, 0.05) var repeat_chance := 0.25
# Но не больше стольких одинаковых подряд (1 = всегда чередуются)
@export var max_same_in_row := 2

var _idle_left := 0
var _last_action := ""
var _repeat_count := 0

func _ready() -> void:
	if anim_player == null:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		push_warning("MenuMonster: внутри не найден AnimationPlayer")
		return

	# Анимации не должны зацикливаться, иначе сигнал окончания не придёт
	for anim_name in [idle_animation, aggressive_animation, waiting_animation]:
		if anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_NONE
		else:
			push_warning("MenuMonster: нет анимации '%s'. Доступные: %s" % [anim_name, anim_player.get_animation_list()])

	anim_player.speed_scale = animation_speed
	anim_player.animation_finished.connect(_on_animation_finished)
	_idle_left = _random_idle_count()   # начинаем с серии Idle
	_play_next()

func _on_animation_finished(_anim_name: StringName) -> void:
	_play_next()

func _play_next() -> void:
	var next: String
	if _idle_left > 0:
		next = idle_animation
		_idle_left -= 1
	else:
		next = _pick_action()
		_idle_left = _random_idle_count()   # после действия снова серия Idle

	# Если такой анимации нет, играем Idle
	if not anim_player.has_animation(next):
		next = idle_animation
		if not anim_player.has_animation(next):
			return
	anim_player.play(next, blend_time)

func _random_idle_count() -> int:
	return randi_range(idle_repeats_min, maxi(idle_repeats_min, idle_repeats_max))

# Выбирает aggressive или waiting с «памятью»: серии подряд редкие и короткие
func _pick_action() -> String:
	var other := waiting_animation if _last_action == aggressive_animation else aggressive_animation
	var choice: String
	if _last_action == "":
		choice = [aggressive_animation, waiting_animation].pick_random()   # первый выбор свободный
	elif _repeat_count >= max_same_in_row:
		choice = other   # серия уже достаточно длинная, меняем
	else:
		choice = _last_action if randf() < repeat_chance else other

	if choice == _last_action:
		_repeat_count += 1
	else:
		_last_action = choice
		_repeat_count = 1
	return choice
