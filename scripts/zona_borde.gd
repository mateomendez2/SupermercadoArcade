extends ColorRect
## ZONA DE PAGAR (el lugar donde te parás frente a la caja)
## En vez de un piso verde que titila, tiene un borde de "tiritas" fluo que giran alrededor,
## como las hormiguitas de una selección. Lo prende y lo apaga flecha_guia.gd (show / hide).

@export var color_tira: Color = Color(0.78, 1.0, 0.08)       # Verde-amarillo fluo
@export var color_entre_tiras: Color = Color(0.08, 0.08, 0.1) # Oscuro, para que resalte en cualquier piso
@export var color_relleno: Color = Color(0.78, 1.0, 0.08, 0.12) # Un tinte muy suave adentro (no titila)
@export var largo_tira: int = 4      # Largo de cada tirita (en pixeles)
@export var velocidad: float = 16.0  # Cuántos pixeles por segundo avanzan las tiritas
const GROSOR: int = 2                # Grosor del borde

var avance: float = 0.0

func _ready() -> void:
	color = Color(0, 0, 0, 0) # El ColorRect no pinta nada: dibujamos todo en _draw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	avance += delta * velocidad
	queue_redraw()

func _draw() -> void:
	var w: int = int(size.x)
	var h: int = int(size.y)
	draw_rect(Rect2(Vector2.ZERO, size), color_relleno)
	# Recorremos el borde en sentido horario, de a cuadraditos de GROSOR x GROSOR
	var recorrido: Array[Vector2] = []
	for x in range(0, w - GROSOR, GROSOR): recorrido.append(Vector2(x, 0))                 # arriba
	for y in range(0, h - GROSOR, GROSOR): recorrido.append(Vector2(w - GROSOR, y))        # derecha
	for x in range(w - GROSOR, 0, -GROSOR): recorrido.append(Vector2(x, h - GROSOR))       # abajo
	for y in range(h - GROSOR, 0, -GROSOR): recorrido.append(Vector2(0, y))                # izquierda
	for i in range(recorrido.size()):
		var distancia: float = i * GROSOR - avance
		var es_tira: bool = posmod(int(floor(distancia / largo_tira)), 2) == 0
		draw_rect(Rect2(recorrido[i], Vector2(GROSOR, GROSOR)), color_tira if es_tira else color_entre_tiras)
