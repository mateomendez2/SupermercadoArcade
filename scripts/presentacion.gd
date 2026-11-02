extends Control
## PANTALLA DE PRESENTACIÓN (lo primero que aparece al abrir el juego)
## Fondo negro y, una atrás de la otra (cada una aparece y se va con un fundido):
##   1. SANGUCHITO STUDIO (letra Anton)
##   2. Proyecto de estudiantes de la UNRaf (con el logo de la universidad)
##   3. Hecho con Godot (con el logo de Godot)
## Al terminar pasa sola a la pantalla de inicio. Cualquier botón (teclado, mando o mouse) la saltea entera.
## Letras: Anton para el estudio y Poppins para los textos chicos (las dos de Google Fonts, licencia libre OFL:
## assets/font/Anton-OFL.txt y Poppins-OFL.txt). Logo de Godot: Andrea Calabró, CC BY 4.0 (assets/logos).

const RUTA_INICIO: String = "res://scenes/ui/menu_principal.tscn"
const LETRA_ESTUDIO: Font = preload("res://assets/font/Anton-Regular.ttf")
const LETRA_TEXTOS: Font = preload("res://assets/font/Poppins-Regular.ttf")
const RUTA_LOGO_UNRAF: String = "res://assets/logos/unraf.png"
const RUTA_LOGO_GODOT: String = "res://assets/logos/godot_logo.png"

@export var duracion_cada_una: float = 2.4 # Lo que dura cada tarjeta (con sus fundidos)
@export var tiempo_fundido: float = 0.5    # Lo que tarda cada una en aparecer y en irse
@export var color_textos: Color = Color(0.82, 0.8, 0.88) # Gris clarito, para que el nombre y los logos resalten

var saliendo: bool = false
var tarjetas: Array[Control] = []
var actual: Control
var tween: Tween

# --- LETRA NÍTIDA ---
# El juego se dibuja chiquito (576x432) y después se agranda: así el pixel art queda con pixeles grandes,
# pero una letra "normal" como la Anton se ve pixelada. En esta pantalla se dibuja todo directo
# al tamaño de la ventana ("canvas_items"): la letra queda nítida y el pixel art se ve igual.
# Al salir de la pantalla se vuelve al modo de siempre.
func _enter_tree() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

func _exit_tree() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color.BLACK
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1. El estudio
	tarjetas.append(_tarjeta([_texto("SANGUCHITO STUDIO", LETRA_ESTUDIO, 56, Color.WHITE),
		_texto("presenta", LETRA_TEXTOS, 13, color_textos)]))
	# 2. La universidad (si todavía no está el logo, van solo los textos)
	var uni: Array = [_texto("Un proyecto de estudiantes de la", LETRA_TEXTOS, 13, color_textos)]
	if ResourceLoader.exists(RUTA_LOGO_UNRAF):
		uni.append(_logo(RUTA_LOGO_UNRAF, Vector2(200, 120)))
	uni.append(_texto("Universidad Nacional de Rafaela", LETRA_TEXTOS, 18, Color.WHITE))
	tarjetas.append(_tarjeta(uni))
	# 3. Godot
	tarjetas.append(_tarjeta([_texto("Hecho con", LETRA_TEXTOS, 13, color_textos), _logo(RUTA_LOGO_GODOT, Vector2(230, 80))]))

	_mostrar(0)

# Una tarjeta: todo centrado, uno abajo del otro
func _tarjeta(cosas: Array) -> Control:
	var t := Control.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 6)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(caja)
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c in cosas: caja.add_child(c)
	t.modulate.a = 0.0
	t.visible = false
	return t

func _texto(que: String, letra: Font, tamano: int, color: Color) -> Label:
	var l := Label.new()
	l.text = que
	l.add_theme_font_override("font", letra)
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _logo(ruta: String, tamano: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(ruta)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = tamano
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # Los logos no son pixel art: suaves, no pixelados
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# Aparece, se queda, se va y sigue con la próxima (después de la última, a la pantalla de inicio)
func _mostrar(i: int) -> void:
	if saliendo: return
	if i >= tarjetas.size():
		_ir_al_inicio()
		return
	actual = tarjetas[i]
	actual.visible = true
	tween = create_tween()
	tween.tween_property(actual, "modulate:a", 1.0, tiempo_fundido)
	tween.tween_interval(maxf(0.0, duracion_cada_una - tiempo_fundido * 2.0))
	tween.tween_property(actual, "modulate:a", 0.0, tiempo_fundido)
	tween.tween_callback(func():
		actual.visible = false
		_mostrar(i + 1))

# Cualquier botón la saltea entera
func _input(event: InputEvent) -> void:
	if saliendo: return
	var apretado: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not apretado: return
	get_viewport().set_input_as_handled() # Que no llegue a la pantalla de inicio
	saliendo = true
	if tween: tween.kill()
	var t := create_tween()
	t.tween_property(actual, "modulate:a", 0.0, 0.25)
	t.tween_callback(_ir_al_inicio)

func _ir_al_inicio() -> void:
	saliendo = true
	get_tree().change_scene_to_file(RUTA_INICIO)
