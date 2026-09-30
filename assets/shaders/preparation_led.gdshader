shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
    float edge = smoothstep(0.0, 0.22, UV.y) * smoothstep(0.0, 0.22, 1.0 - UV.y);
    ALBEDO = mix(vec3(0.002, 0.008, 0.08), vec3(0.003, 0.065, 0.85), edge);
}
