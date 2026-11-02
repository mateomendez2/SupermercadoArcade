@tool
extends StaticBody2D
## NPC QUIETO
## Un cliente parado que no se mueve: solo hace su animación de "idle" (respirar).
## Sirve como obstáculo que ocupa un lugar, por ejemplo adelante de un mueble como si buscara algo.
## No te saca ítems ni te empuja: solo no te deja pasar.
## En el Inspector elegís hacia dónde mira y qué personaje es (se ve el cambio en el editor).

enum Direccion { ABAJO, ARRIBA, IZQUIERDA, DERECHA }
const ANIMACIONES: Array[StringName] = [&"idle_down", &"idle_up", &"idle_left", &"idle_right"]

# --- LOS PERSONAJES QUE SE PUEDEN ELEGIR ---
# Para sumar uno nuevo: agregalo al final de la lista "Personaje" y de PERSONAJES, con sus 4 dibujos
# (izquierda, arriba, abajo y derecha: 3 cuadritos de 32x32 cada uno, uno al lado del otro).
# Los que barren tienen un solo dibujo (de frente, 4 cuadritos): miran siempre para abajo.
enum Personaje { PELIRROJA, RUBIO, CASTANO, COLORADA, RUBIO_BARRIENDO, CASTANO_BARRIENDO, POLICIA }
const PERSONAJES: Array[Dictionary] = [
	# "dibujos": el principio del nombre de los archivos (después va izquierda/arriba/abajo/derecha.png)
	# "bajar": cuántos pixeles se baja el dibujo (para que los pies queden donde pisa)
	{"dibujos": "res://assets/clientes/pelirroja_", "bajar": 1},
	{"dibujos": "res://assets/clientes/rubio_", "bajar": 1},
	{"dibujos": "res://assets/clientes/castano_", "bajar": 1},
	{"dibujos": "res://assets/clientes/colorada_", "bajar": 1},
	# "solo_de_frente": un único dibujo para todas las direcciones. "cuadritos" y "velocidad": su animación
	{"dibujos": "res://assets/clientes/rubio_barriendo", "bajar": 1, "solo_de_frente": true, "cuadritos": 4, "velocidad": 6.0},
	{"dibujos": "res://assets/clientes/castano_barriendo", "bajar": 1, "solo_de_frente": true, "cuadritos": 4, "velocidad": 6.0},
	# El policía quieto (la escena policia_quieto.tscn ya lo trae elegido)
	{"dibujos": "res://assets/policia_estatico_", "bajar": 1},
]
const DIRECCIONES_ARCHIVO: Dictionary = {&"idle_left": "izquierda", &"idle_up": "arriba", &"idle_down": "abajo", &"idle_right": "derecha"}
const CUADRITOS: int = 3
const VELOCIDAD_IDLE: float = 5.0

@export var mirando: Direccion = Direccion.ARRIBA:
	set(valor):
		mirando = valor
		_actualizar()

@export var personaje: Personaje = Personaje.PELIRROJA:
	set(valor):
		personaje = valor
		_actualizar()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var posicion_original: Vector2
var ya_guardada: bool = false
static var frames_armados: Dictionary = {} # personaje -> SpriteFrames (se arman una sola vez)

func _ready() -> void:
	_actualizar()
	preload("res://scripts/sombra.gd").poner(sprite) # Sombrita a los pies
	if not Engine.is_editor_hint():
		# Cada uno arranca en un momento distinto de la animación, así no "respiran" todos juntos
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count(sprite.animation)
		sprite.speed_scale = randf_range(0.85, 1.15)

func _actualizar() -> void:
	if sprite == null: return
	if not ya_guardada:
		ya_guardada = true
		posicion_original = sprite.position
	var cual: int = clampi(personaje, 0, PERSONAJES.size() - 1)
	var datos: Dictionary = PERSONAJES[cual]
	sprite.sprite_frames = _frames_de(cual, datos)
	sprite.material = null # (el de colores invertidos ya no se usa)
	sprite.position = posicion_original + Vector2(0, datos["bajar"])
	sprite.play(ANIMACIONES[mirando])

# Arma las animaciones de un personaje a partir de sus 4 dibujos
static func _frames_de(cual: int, datos: Dictionary) -> SpriteFrames:
	if frames_armados.has(cual): return frames_armados[cual]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in ANIMACIONES:
		var ruta: String = datos["dibujos"] + ("" if datos.get("solo_de_frente", false) else DIRECCIONES_ARCHIVO[anim]) + ".png"
		if not ResourceLoader.exists(ruta):
			push_warning("NPC quieto: falta el dibujo " + ruta)
			continue
		var hoja: Texture2D = load(ruta)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, datos.get("velocidad", VELOCIDAD_IDLE))
		for i in datos.get("cuadritos", CUADRITOS):
			var cuadrito := AtlasTexture.new()
			cuadrito.atlas = hoja
			cuadrito.region = Rect2(i * 32, 0, 32, 32)
			frames.add_frame(anim, cuadrito)
	frames_armados[cual] = frames
	return frames
