shader_type canvas_item;
render_mode unshaded;

uniform float charge_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;

void vertex() {
    vertex_tint = COLOR;
}

void fragment() {
    vec4 pose = texture(TEXTURE, UV) * vertex_tint;
    float brightness = max(pose.r, max(pose.g, pose.b));
    // Preserve the source armor's dark outlines and value steps at the red peak.
    vec3 charged = vec3(min(brightness * 1.15, 1.0), brightness * 0.14, brightness * 0.25);
    COLOR = vec4(mix(pose.rgb, charged, charge_amount), pose.a);
}
