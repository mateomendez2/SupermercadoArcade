@tool
extends StaticBody2D
## CARTEL AMARILLO DE OFERTA
## El cartel amarillo con la franja roja. Escribe la oferta encima, con la letra del juego (m5x7) a 16 px:
##   arriba, en la franja roja, el número en amarillo ("20%", "2x1"...)
##   abajo, en lo amarillo, la palabra en rojo oscuro ("OFF", "HOY").
## En el Inspector elegís cuál ("Oferta"); se ve el cambio en el editor.
## "Al azar" elige una distinta cada vez que arranca el nivel.
## (No hace falta ponerle un Label a mano: el texto lo dibuja este script.)

const LETRA: Font = preload("res://assets/font/m5x7.ttf")
const TAMANIO_LETRA: int = 16 # m5x7 a 16 px = cada pixel de la letra es un pixel del juego (queda nítida)

# Lo que dice cada opción: [arriba (franja roja), abajo (parte amarilla)]
const TEXTOS: Array = [
	["10%", "OFF"],
	["15%", "OFF"],
	["20%", "OFF"],
	["25%", "OFF"],
	["30%", "OFF"],
	["50%", "OFF"],
	["2x1", "HOY"],
	["3x2", "HOY"],
]
const COLOR_ARRIBA: Color = Color8(253, 216, 53)  # El amarillo del cartel
const COLOR_ABAJO: Color = Color8(136, 12, 6)     # El rojo oscuro del borde de la franja

# Dónde va cada renglón (la línea donde se apoyan las letras, medido desde los pies del cartel)
const ANCHO_CARTEL: float = 32.0
const RENGLON_ARRIBA: float = -16.0 # En la franja roja
const RENGLON_ABAJO: float = 0.0    # En la parte amarilla

@export_enum("10% OFF", "15% OFF", "20% OFF", "25% OFF", "30% OFF", "50% OFF", "2x1", "3x2", "Al azar") var oferta: int = 2:
	set(valor):
		oferta = valor
		if texto: texto.queue_redraw()

var texto: Node2D
var elegida: int = 2

func _ready() -> void:
	elegida = oferta
	if oferta >= TEXTOS.size() and not Engine.is_editor_hint():
		elegida = randi() % TEXTOS.size()
	# Un nodo propio para el texto (va después del dibujo del cartel, así queda encima). No se guarda en la escena.
	texto = Node2D.new()
	texto.draw.connect(_dibujar_texto)
	add_child(texto, false, Node.INTERNAL_MODE_BACK)

func _dibujar_texto() -> void:
	var cual: int = oferta if Engine.is_editor_hint() else elegida
	var renglones: Array = TEXTOS[cual] if cual < TEXTOS.size() else ["??", "???"]
	texto.draw_string(LETRA, Vector2(-ANCHO_CARTEL / 2.0, RENGLON_ARRIBA), renglones[0], HORIZONTAL_ALIGNMENT_CENTER, ANCHO_CARTEL, TAMANIO_LETRA, COLOR_ARRIBA)
	texto.draw_string(LETRA, Vector2(-ANCHO_CARTEL / 2.0, RENGLON_ABAJO), renglones[1], HORIZONTAL_ALIGNMENT_CENTER, ANCHO_CARTEL, TAMANIO_LETRA, COLOR_ABAJO)
