extends RefCounted
## BOTÓN "VOLVER" DE LAS PANTALLAS DEL MENÚ
## Amarillo con letra y borde naranja (igual que los botones de ganaste/perdiste).
## Lo usan las pantallas de niveles y de elegir personaje / ladrones:
##     var boton = preload("res://scripts/boton_volver.gd").armar(self, fundido, 330.0)
## Si la pantalla ya tiene un nodo "BotonVolver" (un Button), usa ese (así se puede mover desde el editor).
## Se maneja a mano con la palanca, como las tarjetas (no usa el foco de Godot).

const AMARILLO: Color = Color8(255, 214, 40)
const AMARILLO_APRETADO: Color = Color8(230, 170, 20)
const BORDE: Color = Color8(232, 96, 8)
const LETRA: Color = Color8(214, 78, 6)
const ILUMINADO: Color = Color(1.18, 1.18, 1.18) # Cuánto se ilumina cuando está elegido
const TAMANO: Vector2 = Vector2(220, 40)
const TAMANO_LETRA: int = 32
const RUTA_LETRAS: String = "res://assets/ui/titulos/volver.png"

# pantalla: la pantalla donde va. debajo_de: el nodo que tiene que quedar por encima (el fundido negro).
# y: a qué altura va (si se arma solo).
static func armar(pantalla: Control, debajo_de: Node, y: float) -> Button:
	var boton: Button = pantalla.get_node_or_null("BotonVolver") as Button
	if boton == null:
		boton = Button.new()
		boton.name = "BotonVolver"
		boton.size = TAMANO
		boton.position = Vector2(round((pantalla.get_viewport_rect().size.x - TAMANO.x) / 2.0), y)
		pantalla.add_child(boton)
		if debajo_de: pantalla.move_child(boton, debajo_de.get_index())
	boton.text = ""
	# Las letras "VOLVER" son un dibujo (assets/ui/titulos/volver.png)
	if boton.get_node_or_null("Letras") == null and ResourceLoader.exists(RUTA_LETRAS):
		var letras = TextureRect.new()
		letras.name = "Letras"
		letras.texture = load(RUTA_LETRAS)
		letras.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tam: Vector2 = letras.texture.get_size()
		letras.set_anchors_preset(Control.PRESET_CENTER)
		letras.offset_left = -floor(tam.x / 2.0)
		letras.offset_top = -floor(tam.y / 2.0) - 1 # Centrado en la parte amarilla (la base de abajo es más gruesa)
		letras.offset_right = letras.offset_left + tam.x
		letras.offset_bottom = letras.offset_top + tam.y
		boton.add_child(letras)
	boton.focus_mode = Control.FOCUS_NONE
	var normal = StyleBoxFlat.new()
	normal.bg_color = AMARILLO
	normal.set_border_width_all(2)
	normal.border_width_bottom = 5
	normal.border_color = BORDE
	normal.set_corner_radius_all(10)
	normal.anti_aliasing = false
	normal.content_margin_bottom = 4
	var apretado = normal.duplicate()
	apretado.bg_color = AMARILLO_APRETADO
	apretado.border_width_bottom = 3
	apretado.content_margin_top = 2
	apretado.content_margin_bottom = 2
	for estado in ["normal", "hover"]: boton.add_theme_stylebox_override(estado, normal)
	for estado in ["pressed", "hover_pressed"]: boton.add_theme_stylebox_override(estado, apretado)
	boton.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for clave in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		boton.add_theme_color_override(clave, LETRA)
	boton.add_theme_font_size_override("font_size", TAMANO_LETRA)
	return boton
