extends Node3D
class_name Door

signal opened
signal closed
signal opened_by_player(door: Door)   # игрок открыл дверь (монстр это «слышит»)

@export var door_leaf: Node3D            # подвижная створка (то, что вращается)
@export var open_forward := true         # галочка: открывается вперёд (иначе назад)
@export var open_angle := 90.0           # на сколько градусов открывается
@export var open_time := 0.8             # длительность открытия/закрытия, сек
@export var start_open := false          # дверь изначально открыта

@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var audio_player: AudioStreamPlayer3D   # необязательно, создастся сам

var is_open := false     # целевое состояние (открыта или закрыта)
var _closed_y := 0.0
var _tween: Tween

func _ready() -> void:
	add_to_group("doors")   # монстр находит двери по этой группе

	# Если створка не назначена в Inspector, пробуем путь из старой двери
	if door_leaf == null:
		door_leaf = get_node_or_null("doorWood2/doorWood2_001") as Node3D
	if door_leaf == null:
		push_warning("Door '%s': не назначена створка (поле Door Leaf)" % name)
		return

	# Плеер для звуков: ищем среди детей створки, иначе создаём сами
	if audio_player == null:
		audio_player = door_leaf.find_child("AudioStreamPlayer3D", true, false) as AudioStreamPlayer3D
	if audio_player == null:
		audio_player = AudioStreamPlayer3D.new()
		door_leaf.add_child(audio_player)

	_closed_y = door_leaf.rotation.y   # запоминаем закрытое положение
	if start_open:
		door_leaf.rotation.y = _closed_y + _open_delta()
		is_open = true

func open(by_player: bool = false) -> void:
	_set_open(true, by_player)

func close() -> void:
	_set_open(false)

func _set_open(value: bool, by_player: bool = false) -> void:
	if door_leaf == null or is_open == value:
		return   # уже в этом состоянии (или идёт к нему)
	is_open = value
	if value and by_player:
		opened_by_player.emit(self)   # сигнал в момент начала открытия

	# Прерываем прошлую анимацию: дверь плавно развернётся из текущего положения
	if _tween and _tween.is_valid():
		_tween.kill()

	_play_sound(open_sound if value else close_sound)

	var target := _closed_y + (_open_delta() if value else 0.0)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(door_leaf, "rotation:y", target, open_time)
	_tween.tween_callback(_on_anim_finished.bind(value))

# Угол открытия со знаком: вперёд = минус, назад = плюс
func _open_delta() -> float:
	var angle := deg_to_rad(open_angle)
	return -angle if open_forward else angle

func _on_anim_finished(was_opening: bool) -> void:
	if was_opening:
		opened.emit()
	else:
		closed.emit()

func _play_sound(sound: AudioStream) -> void:
	if audio_player and sound:
		audio_player.stream = sound
		audio_player.play()
