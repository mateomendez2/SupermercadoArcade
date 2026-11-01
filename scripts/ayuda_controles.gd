extends Control
## AYUDA DE CONTROLES (en las pantallas de antes de jugar)
## Muestra con qué se juega, abajo en una esquina:
##   arriba los 3 botones (azul, rojo, amarillo) y abajo las flechas en forma de T invertida.
##   - Sin mando: las teclas (J K L y las flechas; en el modo 2 jugadores, el J1 tiene C V B y W A S D).
##   - Con mando de Xbox o PlayStation: sus botones de colores (A B X / cruz círculo cuadrado) y la cruceta.
##   - Otro mando (tablero arcade): los botones de colores lisos y la cruceta.
## Cambia sola si se conecta o desconecta un mando, y cada tecla se hunde cuando la apretás.
##
## Cómo usarla desde una pantalla:
##   const AyudaControles = preload("res://scripts/ayuda_controles.gd")
##   AyudaControles.poner(self, "", Vector2(12, 338))          # modo 1 jugador
##   AyudaControles.poner(self, "p1_", Vector2(12, 338), "j1") # modo 2 jugadores, con el cartelito J1 arriba

const IconosMando = preload("res://scripts/iconos_mando.gd")
const CARPETA: String = "res://assets/ui/controles/"
const COLORES: Array[String] = ["azul", "rojo", "amarillo"]
const BOTON_LISO: Dictionary = {
	"azul": "res://assets/BotonAzul.png",
	"rojo": "res://assets/BotonRojoAnim.png",
	"amarillo": "res://assets/BotonAmarillo.png",
}
const FLECHAS: Array[String] = ["arriba", "izquierda", "abajo", "derecha"]
const ACCION_FLECHA: Dictionary = {"arriba": "move_up", "abajo": "move_down", "izquierda": "move_left", "derecha": "move_right"}
const UI_FLECHA: Dictionary = {"arriba": "ui_up", "abajo": "ui_down", "izquierda": "ui_left", "derecha": "ui_right"}
const LETRA_J1: Dictionary = {"arriba": "w", "izquierda": "a", "abajo": "s", "derecha": "d"}

# --- MEDIDAS (en pixeles de pantalla) ---
const PASO_X: float = 30.0 # Cada cuánto va una tecla (los dibujos tienen bordes transparentes)
const PASO_Y: float = 28.0
const TAM: Vector2 = Vector2(92, 88)

var prefijo: String = ""
var tipo: String = "teclado"
var botones: Dictionary = {}  # color -> TextureRect
var flechas: Dictionary = {}  # dirección -> TextureRect (teclado)
var cruceta: TextureRect      # (mando)
var tex_cruceta: Dictionary = {}

static func poner(pantalla: Node, quien: String, posicion: Vector2, cartel: String = "") -> Control:
	var ayuda = load("res://scripts/ayuda_controles.gd").new()
	ayuda.prefijo = quien
	ayuda.position = posicion
	pantalla.add_child(ayuda)
	# Que quede abajo del fundido a negro de la pantalla (si no, se vería encima del negro)
	var fundido = pantalla.find_child("Fundido", true, false)
	if fundido and fundido.get_parent() == pantalla:
		pantalla.move_child(ayuda, fundido.get_index())
	if cartel != "":
		var etiqueta := TextureRect.new()
		etiqueta.texture = load("res://assets/ui/modo/" + cartel + ".png")
		etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ayuda.add_child(etiqueta)
		etiqueta.position = Vector2(round((TAM.x - etiqueta.texture.get_width()) / 2.0), -etiqueta.texture.get_height() - 2)
	return ayuda

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = TAM
	for i in COLORES.size():
		var b := _cuadrito(Vector2(i * PASO_X, 0))
		botones[COLORES[i]] = b
	var lugares := {"arriba": Vector2(PASO_X, PASO_Y), "izquierda": Vector2(0, PASO_Y * 2), "abajo": Vector2(PASO_X, PASO_Y * 2), "derecha": Vector2(PASO_X * 2, PASO_Y * 2)}
	for d in FLECHAS:
		flechas[d] = _cuadrito(lugares[d])
	cruceta = TextureRect.new()
	cruceta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cruceta.position = Vector2(round((TAM.x - 48) / 2.0) - 1, PASO_Y + 6)
	add_child(cruceta)
	tex_cruceta[""] = load(CARPETA + "cruceta.png")
	for d in FLECHAS:
		tex_cruceta[d] = load(CARPETA + "cruceta_" + d + ".png")
	_armar()
	Input.joy_connection_changed.connect(func(_m, _c): _armar.call_deferred())

func _cuadrito(pos: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = pos
	var a := AtlasTexture.new()
	a.region = Rect2(0, 0, 32, 32)
	t.texture = a
	add_child(t)
	return t

# Pone las teclas o los botones del mando, según con qué se juegue ahora
func _armar() -> void:
	var mando: int = IconosMando.mando_de(prefijo)
	tipo = "teclado" if mando < 0 else IconosMando.tipo_de_mando(mando)
	for c in COLORES:
		var ruta: String = BOTON_LISO[c]
		if tipo == "teclado":
			ruta = IconosMando.TECLAS.get(prefijo, IconosMando.TECLAS[""])[c]
		elif IconosMando.MANDOS.has(tipo):
			ruta = IconosMando.MANDOS[tipo][c]
		botones[c].texture.atlas = load(ruta)
	for d in FLECHAS:
		var nombre: String = ("tecla_" + LETRA_J1[d]) if prefijo == "p1_" else ("flecha_" + d)
		flechas[d].texture.atlas = load(CARPETA + nombre + ".png")
		flechas[d].visible = tipo == "teclado"
	cruceta.visible = tipo != "teclado"

# Cada tecla se hunde mientras la apretás
func _process(_delta: float) -> void:
	for c in COLORES:
		_hundir(botones[c], _apretado(prefijo + "btn_" + c))
	var apretada: String = ""
	for d in FLECHAS:
		var si: bool = _apretado(prefijo + ACCION_FLECHA[d]) or (prefijo == "" and _apretado(UI_FLECHA[d]))
		_hundir(flechas[d], si)
		if si and apretada == "": apretada = d
	cruceta.texture = tex_cruceta[apretada]

func _apretado(accion: String) -> bool:
	return InputMap.has_action(accion) and Input.is_action_pressed(accion)

func _hundir(t: TextureRect, si: bool) -> void:
	var x: float = 32.0 if si else 0.0
	if t.texture.region.position.x != x:
		t.texture.region = Rect2(x, 0, 32, 32)
