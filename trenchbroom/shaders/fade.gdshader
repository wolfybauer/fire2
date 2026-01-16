shader_type spatial;
//render_mode depth_draw_opaque, depth_prepass_alpha, blend_mix;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D _albedo : source_color;

void fragment() {
    ALBEDO = texture(_albedo, UV).rgb;
	ALPHA = opacity;
}
