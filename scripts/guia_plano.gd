extends Sprite2D
## GUÍA DEL PLANO
## Es el dibujo de la hoja cuadriculada pasado a escala (1 cuadradito = 1 tile de 32 px),
## para ir poniendo los objetos encima en el editor.
##  - Negro: obstáculos fijos   - Naranja: ítems   - Violeta: caja registradora
##  - Celeste: entrada (dejar libre)   - Verde: lugares para cajas   - Rosa: charcos
##  - Rojo: recorrido de los NPC
## Solo se ve en el editor: cuando arranca el juego se borra sola.
## Se puede esconder con el ojito, y cuando termines el nivel, borrá este nodo.

func _ready() -> void:
	queue_free()
