shader_type canvas_item;

// Estos "uniforms" aparecerán en el Inspector de Godot para que los modifiques sin tocar el código
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.6); // Color blanco semitransparente
uniform float shine_speed : hint_range(0.0, 10.0) = 0.75; // Velocidad del brillo
uniform float shine_size : hint_range(0.01, 1.0) = 0.1; // Grosor de la línea
uniform float shine_angle : hint_range(0.0, 360.0) = 45.0; // Ángulo diagonal

void fragment() {
    // 1. Obtenemos el color original de la manzana
    vec4 original_color = texture(TEXTURE, UV);
    
    // 2. Calculamos el ángulo de inclinación
    float rad = radians(shine_angle);
    vec2 rotated_uv = vec2(
        UV.x * cos(rad) - UV.y * sin(rad),
        UV.x * sin(rad) + UV.y * cos(rad)
    );
    
    // 3. Hacemos que la línea se mueva a lo largo del tiempo
    // Usamos fract() para que se repita infinitamente
    float pos = fract(TIME * shine_speed) * 2.0 - 0.5;
    
    // 4. Calculamos si el píxel actual está dentro de esa línea
    float distance = abs(rotated_uv.x - pos);
    float shine = step(distance, shine_size);
    
    // 5. Aplicamos el brillo SOLO a los píxeles que no son transparentes
    COLOR = original_color;
    if (original_color.a > 0.0) {
        COLOR.rgb = mix(original_color.rgb, shine_color.rgb, shine * shine_color.a);
    }
}