shader_type spatial;
render_mode unshaded, cull_front;
uniform float thickness = 0.002;
void vertex() { VERTEX += NORMAL * thickness; }
void fragment() { ALBEDO = vec3(0.018, 0.027, 0.05); }
