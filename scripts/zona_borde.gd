extends ColorRect
## ZONA DE PAGAR (el lugar donde te parás frente a la caja)
## Cuatro esquinitas que titilan suave, igual que las que marcan dónde pararse para agarrar
## un producto (pero del verde del billete). Lo prende y lo apaga flecha_guia.gd (show / hide).

@export var color_esquina: Color = Color8(150, 220, 120) # Verde del billete de la billetera
const LARGO_ESQUINA: int = 5   # Largo de cada patita de la esquina (en pixeles)
const GROSOR_ESQUINA: int = 2  # Grosor de la esquina
const MARGEN: int = -1         # Cuánto se abren las esquinas por fuera de la zona (negativo = hacia adentro)
const TITILAR_MIN: float = 0.55 # Opacidad más baja del titileo (1 = no titila)
const TITILAR_TIEMPO: float = 0.5 # Segundos de cada ida o vuelta del titileo

var tiempo: float = 0.0

func _ready() -> void:
	color = Color(0, 0, 0, 0) # El ColorRect no pinta nada: dibujamos las esquinas en _draw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		tiempo = 0.0
		return
	# Titileo suave (de 1 a TITILAR_MIN y vuelta)
	tiempo += delta
	var onda: float = (cos(tiempo * PI / TITILAR_TIEMPO) + 1.0) / 2.0
	self_modulate.a = lerpf(TITILAR_MIN, 1.0, onda)

func _draw() -> void:
	var borde: Color = color_esquina.darkened(0.7)
	var izq: float = -MARGEN
	var arr: float = -MARGEN
	var der: float = size.x + MARGEN
	var aba: float = size.y + MARGEN
	# Una L por cada punta: (x, y, hacia dónde van las patitas)
	for punta in [[izq, arr, 1, 1], [der, arr, -1, 1], [izq, aba, 1, -1], [der, aba, -1, -1]]:
		_esquina(Vector2(punta[0], punta[1]), punta[2], punta[3], borde)

# Dibuja una L con borde oscuro. "esquina" es la punta de afuera; sx/sy dicen hacia dónde crece.
func _esquina(esquina: Vector2, sx: int, sy: int, borde: Color) -> void:
	# Las dos patitas como rectángulos (ya dados vuelta según la punta)
	var horizontal := _caja(esquina, Vector2(LARGO_ESQUINA, GROSOR_ESQUINA), sx, sy)
	var vertical := _caja(esquina, Vector2(GROSOR_ESQUINA, LARGO_ESQUINA), sx, sy)
	# Primero el borde (1 pixel más grande para cada lado), después el color
	draw_rect(horizontal.grow(1), borde)
	draw_rect(vertical.grow(1), borde)
	draw_rect(horizontal, color_esquina)
	draw_rect(vertical, color_esquina)

func _caja(esquina: Vector2, tam: Vector2, sx: int, sy: int) -> Rect2:
	var x: float = esquina.x if sx > 0 else esquina.x - tam.x
	var y: float = esquina.y if sy > 0 else esquina.y - tam.y
	return Rect2(x, y, tam.x, tam.y)
