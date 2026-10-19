extends Control
## CORAZONES DE LOS MINIJUEGOS
## Columna de corazones al costado derecho del cartel del minijuego.
## Cada error apaga un corazón (se pone gris), empezando por el de arriba.
## Se puede usar en cualquier QTE:
##   var corazones = CorazonesQTE.new()
##   cartel.add_child(corazones)
##   corazones.armar(5)        -> al empezar el minijuego
##   corazones.perder_vida()   -> en cada error

const TEX_LLENO = preload("res://assets/ui/qte/corazon.png")
const TEX_VACIO = preload("res://assets/ui/qte/corazon_gris.png")
const RUTA_SONIDO_VIDA_PERDIDA: String = "res://assets/audio/VidaPerdida.wav" # El "bup-buuu" de error
const VOLUMEN_VIDA_PERDIDA: float = -5.0
const SEPARACION: float = 3.0     # Espacio entre corazón y corazón
const DISTANCIA_CARTEL: float = 5.0 # Cuánto se separa del borde derecho del cartel

var corazones: Array[TextureRect] = []
var vidas: int = 0
var sonido: AudioStreamPlayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sonido = AudioStreamPlayer.new()
	sonido.stream = load(RUTA_SONIDO_VIDA_PERDIDA)
	sonido.volume_db = VOLUMEN_VIDA_PERDIDA
	add_child(sonido)

# Crea los corazones (todos llenos) y los centra al costado del cartel
func armar(cantidad: int) -> void:
	for c in corazones:
		c.queue_free()
	corazones.clear()
	vidas = cantidad

	var cartel = get_parent() as Control
	var alto_corazon: float = TEX_LLENO.get_height()
	var alto_total: float = cantidad * alto_corazon + (cantidad - 1) * SEPARACION
	position = Vector2(cartel.size.x + DISTANCIA_CARTEL, round((cartel.size.y - alto_total) / 2.0))

	for i in cantidad:
		var c = TextureRect.new()
		c.texture = TEX_LLENO
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = Vector2(0, i * (alto_corazon + SEPARACION))
		c.pivot_offset = TEX_LLENO.get_size() / 2.0
		add_child(c)
		corazones.append(c)

# Apaga el corazón de más arriba que siga lleno, con un saltito
func perder_vida() -> void:
	if vidas <= 0: return
	var c: TextureRect = corazones[corazones.size() - vidas]
	vidas -= 1
	sonido.play()
	c.texture = TEX_VACIO
	c.modulate = Color(2.0, 2.0, 2.0) # Destello blanco
	c.scale = Vector2(1.4, 1.4)
	var t = create_tween().set_parallel(true)
	t.tween_property(c, "modulate", Color.WHITE, 0.25)
	t.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
