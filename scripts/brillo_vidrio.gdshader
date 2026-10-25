shader_type canvas_item;
// Brillo para el vidrio de las heladeras: dibuja SOLO la franja de luz que pasa en diagonal
// (el resto queda transparente). Mismos valores que el brillo de los productos.
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform float shine_speed : hint_range(0.0, 10.0) = 0.75;
uniform float shine_size : hint_range(0.01, 1.0) = 0.1;
uniform float shine_angle : hint_range(0.0, 360.0) = 45.0;

void fragment() {
    float rad = radians(shine_angle);
    vec2 rotated_uv = vec2(
        UV.x * cos(rad) - UV.y * sin(rad),
        UV.x * sin(rad) + UV.y * cos(rad)
    );
    float pos = fract(TIME * shine_speed) * 2.0 - 0.5;
    float shine = step(abs(rotated_uv.x - pos), shine_size);
    COLOR = vec4(shine_color.rgb, shine * shine_color.a * texture(TEXTURE, UV).a);
}
