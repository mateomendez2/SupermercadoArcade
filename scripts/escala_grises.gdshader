shader_type canvas_item;

void fragment() {
    // Tomamos el color original del dibujo
    vec4 col = texture(TEXTURE, UV);
    // Fórmula matemática universal para convertir a Blanco y Negro
    float gris = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    // Reemplazamos los colores, pero mantenemos el fondo transparente original (col.a)
    COLOR = vec4(gris, gris, gris, col.a);
}