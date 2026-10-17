extends CharacterBody3D

# Настройки движения
@export var move_speed := 5.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003

# Ссылка на узел Head
@onready var head: Node3D = $Head

# Гравитация (стандартное значение из настроек проекта)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# Захватываем курсор мыши при старте игры
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Обработка движения мыши для обзора
	if event is InputEventMouseMotion:
		# Горизонтальный обзор (yaw) вращает всё тело
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Вертикальный обзор (pitch) вращает только Head
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		# Ограничиваем угол наклона Head, чтобы камера не переворачивалась
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	# --- Гравитация и прыжок ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# --- Движение ---
	# Получаем вектор ввода (x - влево/вправо, y - вперед/назад)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	# Преобразуем направление ввода в мировые координаты, основываясь на повороте тела
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		# Плавное замедление, если нет ввода
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	# Применяем движение и скольжение по поверхностям
	move_and_slide()
