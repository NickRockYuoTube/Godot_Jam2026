extends CharacterBody3D

@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var head: Node3D = $Head
@export var player: Node3D
@export var move_speed := 5.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.003
@export var acceleration := 15.0
@export var friction := 10.0

# Гистерезис — задержка переключения (в кадрах)
@export var look_delay_frames := 10  # Сколько кадров нужно "смотреть", чтобы переключить

var current_target: Node = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var can_look := false
var frames_looking := 0      # Счётчик кадров, когда луч на цели
var frames_not_looking := 0  # Счётчик кадров, когда луч не на цели

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ray.add_exception(self)
	
	await get_tree().create_timer(1.0).timeout
	can_look = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	var new_target: Node = null
	
	if can_look and ray.is_colliding():
		var collider = ray.get_collider()
		if collider.has_method("on_looked_at"):
			new_target = collider
	
	# --- ГИСТЕРЕЗИС ---
	if new_target == current_target:
		# Цель та же — сбрасываем счётчики
		frames_looking = 0
		frames_not_looking = 0
	else:
		if new_target != null:
			# Луч попал на новый объект
			frames_looking += 1
			frames_not_looking = 0
			
			if frames_looking >= look_delay_frames:
				# Устойчиво смотрим — переключаем
				if current_target and current_target.has_method("on_looked_away"):
					current_target.on_looked_away()
				if new_target.has_method("on_looked_at"):
					new_target.on_looked_at()
				current_target = new_target
				frames_looking = 0
		else:
			# Луч ушёл с объекта
			frames_not_looking += 1
			frames_looking = 0
			
			if frames_not_looking >= look_delay_frames:
				# Устойчиво отвели взгляд — переключаем
				if current_target and current_target.has_method("on_looked_away"):
					current_target.on_looked_away()
				current_target = null
				frames_not_looking = 0
	
	# --- Гравитация и прыжок ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# --- Движение ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

	move_and_slide()
