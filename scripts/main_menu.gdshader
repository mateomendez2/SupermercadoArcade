shader_type canvas_item;

// Esta variable aparecerá en tu Inspector para que cambies la velocidad sin tocar código
uniform float velocidad = 0.05; 

void fragment() {
	// Le decimos al dibujo que se deslice en el eje X usando el Reloj del juego (TIME)
    COLOR = texture(TEXTURE, vec2(UV.x + TIME * velocidad, UV.y));
}