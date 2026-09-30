shader_type spatial;
render_mode cull_disabled, specular_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz;
    // Keep the physical FIFA paint legible through the decorative grass.
    bool arc = abs(length(p - vec2(0.0, -41.5)) - 9.15) < 0.085 && p.y > -36.0;
    bool box_line = abs(p.y + 36.0) < 0.085 && abs(p.x) < 20.2;
    if (arc || box_line) discard;
    ALBEDO = COLOR.rgb * 0.72;
    ROUGHNESS = 1.0;
}
