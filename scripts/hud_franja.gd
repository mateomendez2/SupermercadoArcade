extends CanvasLayer
## LA FRANJA ARCADE DE ARRIBA
## De izquierda a derecha: NIVEL x | reloj 01:30 (en el medio) | LISTA
## Debajo de "LISTA" cuelga el ticket con los productos (sale "impreso" al empezar el nivel).
##
## Todo se arma por código con las imágenes de res://assets/ui/hud/ (estilo del título de Nati).
## La crea gestor_interfaz.gd, y ella sola escucha al GameManager para actualizarse.

signal ticket_impreso # Avisa cuando el ticket terminó de salir de la "impresora"

const CARPETA: String = "res://assets/ui/hud/"

# --- MEDIDAS (en pixeles de pantalla) ---
const ALTO_FRANJA: int = 26     # Alto de la parte negra
const Y_TEXTO: int = 4          # Altura de las letras dentro de la franja
const MARGEN: int = 8           # Separación con los bordes de la pantalla
const ESPACIO_ROTULO: int = 4   # Entre "NIVEL" y su número
const ESPACIO_GRUPO: int = 16   # Entre un grupo y el siguiente
const PASO_DIGITO: int = 12     # Cada cuánto va un dígito
const ANCHO_DOS_PUNTOS: int = 9 # Lo que ocupan los ":" del reloj (más angostos que un número)
const PASO_ICONO: int = 36      # Cada cuánto va un producto en el ticket
const ALTO_TICKET: int = 48
const SEGUNDOS_ALERTA: int = 10 # Debajo de esto, el reloj titila en rojo

# Colores del título "MANDADOS A FULL"
const COLOR_BORDE: Color = Color8(191, 54, 12)
const COLOR_RELIEVE: Color = Color8(110, 28, 6)

var tex: Dictionary = {} # nombre de imagen -> textura
var ancho_pantalla: float = 576.0
var raiz: Control

var caja_nivel: Control
var caja_tiempo: Control
var grupo_lista: Control
var caja_contador: Control

var ventana_ticket: Control # Recorta el ticket: así parece que sale de adentro de la franja
var ticket: NinePatchRect
var ranura: ColorRect
var ancho_ticket: float = 0.0
var iconos: Dictionary = {}  # nombre del producto -> TextureRect
var tildes: Dictionary = {}  # nombre del producto -> TextureRect del tilde
var sello: Label
var tween_sello: Tween

var material_gris: ShaderMaterial
var tiempo_mostrado: int = -1
var tween_alerta: Tween
# Modo 2 jugadores: el ticket cuelga en el medio de la pantalla (así no le tapa más a uno que al otro).
# El rótulo "LISTA" queda donde siempre. Lo prende gestor_interfaz.gd.
var ticket_al_medio: bool = false

func _ready() -> void:
	layer = 5 # Por encima del juego y la interfaz, por debajo del cartel "NIVEL X" (capa 10)
	ancho_pantalla = get_viewport().get_visible_rect().size.x

	_cargar_texturas()
	material_gris = ShaderMaterial.new()
	material_gris.shader = load("res://scripts/escala_grises.gdshader")

	_armar_franja()

	# Escuchamos al GameManager
	GameManager.list_generated.connect(_on_lista_generada)
	GameManager.item_collected.connect(_on_item_juntado)
	GameManager.item_dropped.connect(_on_item_perdido)
	GameManager.time_updated.connect(_on_tiempo)
	#GameManager.lista_lista_para_pagar.connect(_mostrar_sello) # Sello "¡A LA CAJA!" desactivado
	GameManager.lista_incompleta.connect(_ocultar_sello)

	# El Tutorial arma su lista ANTES de que exista la interfaz, así que la leemos ahora
	if GameManager.target_list.size() > 0:
		_on_lista_generada(GameManager.target_list)
	_on_tiempo(int(GameManager.tiempo_restante))

# =====================================================================
# ARMADO
# =====================================================================
func _cargar_texturas() -> void:
	var nombres = ["txt_nivel", "txt_lista", "num_barra", "num_dos_puntos", "ticket", "tilde"]
	for i in range(10):
		nombres.append("num_" + str(i))
	for nombre in nombres:
		tex[nombre] = load(CARPETA + nombre + ".png")

func _armar_franja() -> void:
	raiz = Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fondo negro + filo rojizo con relieve (como el borde del título)
	_rectangulo(Rect2(0, 0, ancho_pantalla, ALTO_FRANJA), Color.BLACK)
	_rectangulo(Rect2(0, ALTO_FRANJA, ancho_pantalla, 1), COLOR_BORDE)
	_rectangulo(Rect2(0, ALTO_FRANJA + 1, ancho_pantalla, 1), COLOR_RELIEVE)

	# NIVEL x
	var x: float = MARGEN
	_imagen("txt_nivel", Vector2(x, Y_TEXTO), raiz)
	x += tex["txt_nivel"].get_width() + ESPACIO_ROTULO
	caja_nivel = _caja(Vector2(x, Y_TEXTO))
	x += _ancho_numero(2) + ESPACIO_GRUPO

	# RELOJ 01:30, centrado en la franja
	caja_tiempo = _caja(Vector2(roundf((ancho_pantalla - _ancho_reloj()) / 2.0), Y_TEXTO))

	# LISTA (sin números; siempre en el mismo lugar, centrado arriba del ticket)
	grupo_lista = _caja(Vector2(0, Y_TEXTO))
	_imagen("txt_lista", Vector2.ZERO, grupo_lista)
	_ubicar_rotulo_lista()

	# El ticket: vive adentro de una "ventana" que lo recorta
	ventana_ticket = _caja(Vector2.ZERO)
	ventana_ticket.clip_contents = true
	ticket = NinePatchRect.new()
	ticket.texture = tex["ticket"]
	ticket.patch_margin_left = 4  # Los bordes de los costados no se estiran
	ticket.patch_margin_right = 4
	ticket.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE # El centro se repite
	ticket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ventana_ticket.add_child(ticket)

	# La "ranura" de la impresora: una rayita negra que corta el filo de la franja
	ranura = ColorRect.new()
	ranura.color = Color.BLACK
	ranura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(ranura)

func _armar_ticket(lista: Array[ItemData]) -> void:
	# Borramos lo del nivel anterior
	if tween_sello: tween_sello.kill()
	_vaciar(ticket)
	iconos.clear()
	tildes.clear()

	# Tamaño y lugar: pegado a la derecha, debajo de la franja.
	# Tiene un ancho mínimo, así con pocos productos queda justo debajo del rótulo "LISTA"
	var ancho_productos: int = lista.size() * PASO_ICONO + 12
	ancho_ticket = maxi(ancho_productos, _ancho_minimo_ticket())
	var primer_icono_x: int = (int(ancho_ticket) - ancho_productos) / 2 + 8 # Productos centrados
	var x = ancho_pantalla - MARGEN - ancho_ticket
	if ticket_al_medio:
		x = round((ancho_pantalla - ancho_ticket) / 2.0)
	ventana_ticket.position = Vector2(x, ALTO_FRANJA + 2)
	ventana_ticket.size = Vector2(ancho_ticket, ALTO_TICKET + 2)
	ticket.size = Vector2(ancho_ticket, ALTO_TICKET)
	ticket.position = Vector2(0, -ALTO_TICKET) # Escondido "adentro de la impresora"
	ranura.position = Vector2(x - 3, ALTO_FRANJA)
	ranura.size = Vector2(ancho_ticket + 6, 2)

	# Un ícono por producto (al doble de tamaño, como en la libreta)
	for i in range(lista.size()):
		var item: ItemData = lista[i]
		var icono = TextureRect.new()
		icono.texture = item.icon
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_SCALE
		icono.size = Vector2(32, 32)
		icono.pivot_offset = Vector2(16, 16)
		icono.position = Vector2(primer_icono_x + i * PASO_ICONO, 6)
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticket.add_child(icono)
		iconos[item.item_name] = icono

		var tilde = _imagen("tilde", Vector2(21, 22), icono)
		tilde.hide()
		tildes[item.item_name] = tilde

	# El sello "¡A LA CAJA!" (aparece cuando completás la lista)
	sello = Label.new()
	sello.text = "¡A LA\nCAJA!"
	sello.add_theme_font_size_override("font_size", 32)
	sello.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
	sello.add_theme_color_override("font_outline_color", Color.WHITE)
	sello.add_theme_constant_override("outline_size", 6)
	sello.add_theme_constant_override("line_spacing", -8)
	sello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sello.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sello.size = Vector2(ancho_ticket, ALTO_TICKET - 4)
	sello.pivot_offset = sello.size / 2.0
	sello.rotation_degrees = -8.0
	sello.hide()
	ticket.add_child(sello)


# =====================================================================
# ACTUALIZACIONES
# =====================================================================
func poner_nivel(numero: int) -> void:
	_escribir_numero(caja_nivel, str(numero))

func _on_lista_generada(lista: Array[ItemData]) -> void:
	_armar_ticket(lista)
	_actualizar_contador()
	_frenar_alerta()
	tiempo_mostrado = -1

func _on_tiempo(tiempo: int) -> void:
	tiempo = maxi(tiempo, 0)
	if tiempo == tiempo_mostrado:
		return # El GameManager avisa en cada frame; solo redibujamos cuando cambia el segundo
	tiempo_mostrado = tiempo
	_escribir_reloj(tiempo)

	# Últimos segundos: ¡todo titila en rojo!
	if tiempo > 0 and tiempo <= SEGUNDOS_ALERTA and GameManager.juego_activo:
		_empezar_alerta()
	else:
		_frenar_alerta()


func _actualizar_contador() -> void:
	pass # Ya no mostramos "n/m" al lado de LISTA (los tildes del ticket ya dicen qué tenés)

# Ancho mínimo del ticket (el de siempre). "LISTA" se centra arriba de ese ancho y no se mueve más:
# si la lista crece, el ticket se estira hacia la izquierda y el rótulo queda en el mismo lugar.
func _ancho_minimo_ticket() -> int:
	return tex["txt_lista"].get_width() + ESPACIO_ROTULO + int(_ancho_numero(3)) + 4

func _ubicar_rotulo_lista() -> void:
	var centro: float = ancho_pantalla - MARGEN - _ancho_minimo_ticket() / 2.0
	grupo_lista.position.x = roundf(centro - tex["txt_lista"].get_width() / 2.0)

func _on_item_juntado(item: ItemData) -> void:
	_actualizar_contador()
	if not iconos.has(item.item_name): return
	var icono: TextureRect = iconos[item.item_name]
	icono.material = material_gris # Gris = ya lo tenemos
	tildes[item.item_name].show()
	var salto = create_tween()
	salto.tween_property(icono, "scale", Vector2(1.25, 1.25), 0.1)
	salto.tween_property(icono, "scale", Vector2.ONE, 0.1)

func _on_item_perdido(item: ItemData) -> void:
	_actualizar_contador()
	if not iconos.has(item.item_name): return
	var icono: TextureRect = iconos[item.item_name]
	icono.material = null # Vuelve a color = hay que ir a buscarlo de nuevo
	tildes[item.item_name].hide()
	var parpadeo = create_tween()
	parpadeo.tween_property(icono, "modulate", Color.RED, 0.1)
	parpadeo.tween_property(icono, "modulate", Color.WHITE, 0.1)
	parpadeo.tween_property(icono, "modulate", Color.RED, 0.1)
	parpadeo.tween_property(icono, "modulate", Color.WHITE, 0.1)

# =====================================================================
# ANIMACIONES
# =====================================================================
# El ticket sale de la franja a "tirones", como una impresora de supermercado
func imprimir_ticket() -> void:
	ticket.position.y = -ALTO_TICKET
	var impresion = create_tween()
	var pasos = 6
	for i in range(1, pasos + 1):
		impresion.tween_property(ticket, "position:y", -ALTO_TICKET + ALTO_TICKET * i / float(pasos), 0.1)
		impresion.tween_interval(0.06)
	await impresion.finished
	ticket_impreso.emit()

func _mostrar_sello() -> void:
	if sello == null: return
	if tween_sello: tween_sello.kill()
	sello.scale = Vector2(3.0, 3.0)
	sello.modulate.a = 0.0
	sello.show()
	tween_sello = create_tween()
	tween_sello.set_parallel(true)
	tween_sello.tween_property(sello, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween_sello.tween_property(sello, "modulate:a", 1.0, 0.2)
	# ¡PUM! El ticket se sacude cuando cae el sello
	tween_sello.chain()
	tween_sello.set_parallel(false)
	for i in range(4):
		tween_sello.tween_property(ticket, "position:x", randf_range(-2.0, 2.0), 0.04)
	tween_sello.tween_property(ticket, "position:x", 0.0, 0.04)

func _ocultar_sello() -> void:
	if tween_sello: tween_sello.kill()
	if sello: sello.hide()
	ticket.position.x = 0.0

func _empezar_alerta() -> void:
	if tween_alerta and tween_alerta.is_valid(): return # Ya está titilando
	tween_alerta = create_tween().set_loops()
	tween_alerta.tween_property(caja_tiempo, "modulate", Color(1.0, 0.3, 0.25), 0.25)
	tween_alerta.tween_property(caja_tiempo, "modulate", Color.WHITE, 0.25)

func _frenar_alerta() -> void:
	if tween_alerta: tween_alerta.kill()
	if caja_tiempo: caja_tiempo.modulate = Color.WHITE

# =====================================================================
# AYUDANTES
# =====================================================================
func _escribir_numero(caja: Control, texto: String) -> void:
	_vaciar(caja)
	for i in range(texto.length()):
		var letra = texto[i]
		var nombre = "num_barra" if letra == "/" else "num_" + letra
		if tex.has(nombre):
			_imagen(nombre, Vector2(i * PASO_DIGITO, 0), caja)

# El reloj en minutos y segundos: 90 -> "01:30". Los ":" son más angostos que los números.
func _escribir_reloj(segundos: int) -> void:
	_vaciar(caja_tiempo)
	var texto = "%02d%02d" % [int(segundos / 60.0), segundos % 60]
	var x: float = 0.0
	for i in range(4):
		_imagen("num_" + texto[i], Vector2(x, 0), caja_tiempo)
		x += PASO_DIGITO
		if i == 1:
			_imagen("num_dos_puntos", Vector2(x, 0), caja_tiempo)
			x += ANCHO_DOS_PUNTOS

func _ancho_reloj() -> float:
	return 3 * PASO_DIGITO + ANCHO_DOS_PUNTOS + tex["num_0"].get_width()

# Saca los hijos de un nodo EN EL MOMENTO (queue_free solo los borra al final del frame)
func _vaciar(nodo: Node) -> void:
	for hijo in nodo.get_children():
		nodo.remove_child(hijo)
		hijo.queue_free()

func _ancho_numero(digitos: int) -> float:
	return (digitos - 1) * PASO_DIGITO + tex["num_0"].get_width()

func _imagen(nombre: String, pos: Vector2, padre: Node) -> TextureRect:
	var img = TextureRect.new()
	img.texture = tex[nombre]
	img.position = pos
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(img)
	return img

func _caja(pos: Vector2) -> Control:
	var caja = Control.new()
	caja.position = pos
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(caja)
	return caja

func _rectangulo(r: Rect2, color: Color) -> void:
	var rect = ColorRect.new()
	rect.color = color
	rect.position = r.position
	rect.size = r.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(rect)
