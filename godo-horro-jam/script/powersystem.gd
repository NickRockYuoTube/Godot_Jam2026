extends Node
# Autoload: PowerSystem. Хранит заряд фонаря, динамо и состояние лампы.

signal charge_changed(charge: float)
signal level_changed(level: int)          # значения из enum Level
signal flashlight_changed(is_on: bool)
signal moving_changed(is_moving: bool)    # ← НОВОЕ: сигнал для звука коляски

enum Level { FULL, HALF, EMPTY }

const CHARGE_PER_SEC := 1.0 / 90.0   # динамо: полный заряд за 90 с движения
const DRAIN_PER_SEC := 1.0 / 60.0    # фонарь: полный заряд хватает на 60 с
const GREEN_MIN := 0.66              # выше этого значения горит зелёный
const ORANGE_MIN := 0.2              # выше этого значения горит оранжевый, ниже красный

var charge := 0.5
var is_moving := false
var flashlight_on := false
var level: int = Level.HALF

func _ready() -> void:
	level = _calc_level()

func _process(delta: float) -> void:
	var old := charge
	if is_moving:
		charge += CHARGE_PER_SEC * delta
	if flashlight_on:
		charge -= DRAIN_PER_SEC * delta
	charge = clampf(charge, 0.0, 1.0)

	if charge != old:
		charge_changed.emit(charge)
		var new_level := _calc_level()
		if new_level != level:
			level = new_level
			level_changed.emit(level)

	# Заряд кончился, фонарь гаснет
	if flashlight_on and charge <= 0.0:
		set_flashlight(false)

func set_moving(value: bool) -> void:    # ← НОВОЕ: заменяет старую версию
	if is_moving == value:
		return
	is_moving = value
	moving_changed.emit(is_moving)

func toggle_flashlight() -> void:
	set_flashlight(not flashlight_on)

func set_flashlight(value: bool) -> void:
	if value and charge <= 0.0:
		return   # разряжен, включить нельзя
	if flashlight_on == value:
		return
	flashlight_on = value
	flashlight_changed.emit(flashlight_on)

func reset() -> void:   # вызывай при старте/рестарте уровня
	charge = 0.5
	set_moving(false)   # ← НОВОЕ: вместо is_moving = false
	set_flashlight(false)
	level = _calc_level()
	charge_changed.emit(charge)
	level_changed.emit(level)

func _calc_level() -> int:
	if charge > GREEN_MIN:
		return Level.FULL
	if charge > ORANGE_MIN:
		return Level.HALF
	return Level.EMPTY
