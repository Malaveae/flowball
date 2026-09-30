shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec3 grass = texture(albedo_texture, world_position.xz * 0.8).rgb;
    float stripe = mix(0.79, 1.0, step(0.5, fract((world_position.z + 52.5) / 15.0)));
    ALBEDO = grass * stripe * vec3(0.72, 0.72, 0.58);
    ROUGHNESS = 1.0;
}
