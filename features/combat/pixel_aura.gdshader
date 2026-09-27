shader_type canvas_item;
render_mode unshaded;

uniform vec4 frame_bounds = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.01, 0.22, 1.0);
uniform float strength = 0.7;
uniform float radius = 5.0;
uniform vec2 silhouette_scale = vec2(1.0);
uniform float upper_focus = 0.0;
uniform sampler2D silhouette_texture : filter_nearest;
varying float opacity;

void vertex() {
    opacity = COLOR.a;
}

float silhouette(vec2 uv) {
    vec2 frame_uv = (uv - frame_bounds.xy) / (frame_bounds.zw - frame_bounds.xy);
    float focus = mix(1.0, 1.0 - smoothstep(0.52, 0.76, frame_uv.y), upper_focus);
    vec2 pivot = frame_bounds.xy + (frame_bounds.zw - frame_bounds.xy) * vec2(0.5, 0.36);
    uv = pivot + (uv - pivot) / mix(vec2(1.0), silhouette_scale, focus);
    if (any(lessThan(uv, frame_bounds.xy)) || any(greaterThan(uv, frame_bounds.zw))) {
        return 0.0;
    }
    return texture(silhouette_texture, uv).a;
}

void fragment() {
    float halo = 0.0;
    for (int ring = 1; ring <= 3; ring++) {
        vec2 step_uv = TEXTURE_PIXEL_SIZE * radius * float(ring) / 3.0;
        for (int i = 0; i < 12; i++) {
            float angle = float(i) * 6.2831853 / 12.0;
            halo += silhouette(UV + vec2(cos(angle), sin(angle)) * step_uv);
        }
    }
    COLOR = vec4(glow_color.rgb, pow(halo / 36.0, 0.7) * strength * opacity);
}
