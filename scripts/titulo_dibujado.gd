extends RefCounted
## TEXTOS DIBUJADOS
## Pone un dibujo (con las letras de colores, como los carteles "NIVEL X") en lugar del texto de un Label.
## El Label queda donde está (se puede mover desde el editor): el dibujo va centrado adentro de él.
## Los dibujos están en assets/ui/titulos/.
##     preload("res://scripts/titulo_dibujado.gd").poner($Titulo, "res://assets/ui/titulos/elegi_un_nivel.png")

static func poner(etiqueta: Label, ruta: String) -> TextureRect:
	if etiqueta == null or not ResourceLoader.exists(ruta): return null
	etiqueta.text = "" # El texto de siempre ya no se ve (el dibujo lo reemplaza)
	var dibujo = TextureRect.new()
	dibujo.name = "Dibujo"
	dibujo.texture = load(ruta)
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dibujo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	etiqueta.add_child(dibujo)
	# Centrado en el Label, sin estirarse (pixel art)
	var tam: Vector2 = dibujo.texture.get_size()
	dibujo.set_anchors_preset(Control.PRESET_CENTER)
	dibujo.offset_left = -floor(tam.x / 2.0)
	dibujo.offset_top = -floor(tam.y / 2.0)
	dibujo.offset_right = dibujo.offset_left + tam.x
	dibujo.offset_bottom = dibujo.offset_top + tam.y
	return dibujo
