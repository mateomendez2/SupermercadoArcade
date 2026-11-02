extends RefCounted
## SOMBRITA DE LOS PERSONAJES
## Un óvalo oscuro y medio transparente a los pies (jugadores, empleados, clientes quietos, policías y guardia).
## Es solo un dibujo: no tiene colisión ni cambia nada del juego.
## Va como hija del dibujo del personaje y se dibuja ATRÁS de él (show_behind_parent),
## así lo sigue en todo: si el personaje se oculta, se mueve o se hace transparente, la sombra también.
##
## Cómo usarla:
##   preload("res://scripts/sombra.gd").poner($AnimatedSprite2D)

# --- CÓMO SE VE ---
# El óvalo, fila por fila: "#" = sombra, "+" = sombra más suave (el borde), "." = nada.
const FORMA: Array[String] = [
	"..+######+..",
	"+##########+",
	"+##########+",
	"..+######+..",
]
const COLOR: Color = Color(0.12, 0.06, 0.14, 0.26) # Oscura, apenas violácea (queda mejor que negro puro sobre el piso)
const COLOR_BORDE: Color = Color(0.12, 0.06, 0.14, 0.13)
const PIES: int = 10 # Dónde arranca (en pixeles desde el centro del dibujo de 32x32): los pies tapan casi toda la sombra
                     # y asoma apenas alrededor y un pixel por abajo

static var textura: ImageTexture

static func poner(dibujo: Node2D) -> void:
	if dibujo == null or dibujo.get_node_or_null("Sombra") != null: return
	var s := Sprite2D.new()
	s.name = "Sombra"
	s.texture = _textura()
	s.centered = false # Así cae justo en los pixeles (sin medio pixel corrido)
	s.position = Vector2(-FORMA[0].length() / 2, PIES)
	if dibujo is AnimatedSprite2D: s.position += (dibujo as AnimatedSprite2D).offset
	s.show_behind_parent = true
	dibujo.add_child(s, false, Node.INTERNAL_MODE_FRONT) # Interna: no se guarda en las escenas
	dibujo.move_child(s, 0)

# El óvalo pixelado (se arma una sola vez)
static func _textura() -> ImageTexture:
	if textura: return textura
	var img := Image.create(FORMA[0].length(), FORMA.size(), false, Image.FORMAT_RGBA8)
	for y in FORMA.size():
		for x in FORMA[y].length():
			match FORMA[y][x]:
				"#": img.set_pixel(x, y, COLOR)
				"+": img.set_pixel(x, y, COLOR_BORDE)
	textura = ImageTexture.create_from_image(img)
	return textura
