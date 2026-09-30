shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float falloff = pow(max(0.0, 1.0 - length(p)), 3.0);
    ALBEDO = vec3(0.55, 0.68, 1.0);
    ALPHA = falloff * 0.45;
}
