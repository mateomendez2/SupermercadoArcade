shader_type canvas_item;

void fragment() {
    // Leemos el color original del dibujo
    vec4 color_original = texture(TEXTURE, UV);
    // Invertimos los colores (1 menos el color), pero conservamos la transparencia (Alpha) original
    COLOR = vec4(1.0 - color_original.r, 1.0 - color_original.g, 1.0 - color_original.b, color_original.a);
}
