shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(0.08, 1.0, 0.57, 1.0);
varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float value = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 color = mix(tint.rgb * 0.35, vec3(0.78, 1.0, 0.9), value);
    COLOR = vec4(color, source.a) * vertex_tint;
}
