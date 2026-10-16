extends Node2D
## CONFITES DE FESTEJO
## Se usa cuando ganás un minijuego (QTE): tira confites de colores desde
## las dos esquinas de arriba del cartel, durante un poco más de un segundo.
##
## Cómo usarlo desde un QTE:
##     var confites = Confites.new()
##     add_child(confites)
##     await confites.festejar(self)

const DURACION: float = 1.2 # Cuánto dura el festejo (después se borra solo)

# Colores del juego: los del título "MANDADOS A FULL" + los de los botones + el verde
const COLORES: Array[Color] = [
	Color8(250, 255, 150), Color8(255, 235, 51), Color8(255, 134, 0), # amarillos y naranja del título
	Color8(54, 104, 252), Color8(255, 63, 59), Color8(0, 231, 73),    # azul, rojo y verde
	Color8(255, 255, 255),
]

func festejar(qte: Control) -> void:
	# Buscamos el cartel del minijuego para saber dónde están sus esquinas
	var cartel: Control = qte.get_node("FondoCartel")
	var rect: Rect2 = cartel.get_global_rect()
	rect.position -= qte.global_position

	# Un "cañón" de confites en cada esquina de arriba, apuntando hacia adentro y arriba
	_lanzar(rect.position + Vector2(8, 10), Vector2(1.0, -0.45))
	_lanzar(Vector2(rect.end.x - 8, rect.position.y + 10), Vector2(-1.0, -0.45))

	await get_tree().create_timer(DURACION).timeout
	queue_free()

func _lanzar(desde: Vector2, direccion: Vector2) -> void:
	var p = CPUParticles2D.new()
	p.position = desde
	p.one_shot = true
	p.explosiveness = 0.85 # Casi todos salen de golpe
	p.amount = 48
	p.lifetime = DURACION - 0.1
	p.texture = _papelito()

	# Hacia dónde y con qué fuerza salen
	p.direction = direccion.normalized()
	p.spread = 25.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 220) # Después caen sobre el cartel
	p.damping_min = 20.0
	p.damping_max = 45.0

	# Giran mientras caen, como papelitos
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0

	# Cada papelito sale de un color al azar de la lista
	var colores = Gradient.new()
	colores.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var posiciones = PackedFloat32Array()
	var tonos = PackedColorArray()
	for i in range(COLORES.size()):
		posiciones.append(float(i) / COLORES.size())
		tonos.append(COLORES[i])
	colores.offsets = posiciones
	colores.colors = tonos
	p.color_initial_ramp = colores

	# Y se desvanecen al final
	var desvanecer = Gradient.new()
	desvanecer.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	desvanecer.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = desvanecer

	add_child(p)
	p.emitting = true

# Un rectangulito blanco de 2x3 pixeles (el color se lo dan las partículas)
func _papelito() -> Texture2D:
	var img = Image.create(2, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
