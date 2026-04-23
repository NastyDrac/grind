shader_type canvas_item;

// How fast the shimmer sweeps across (higher = faster)
uniform float shimmer_speed : hint_range(0.1, 2.0) = 0.5;
// How wide the shimmer band is
uniform float shimmer_width : hint_range(0.01, 0.5) = 0.2;
// How strongly it shifts toward the shimmer colour (0 = invisible, 1 = full)
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.55;
// Seconds to pause between each sweep
uniform float shimmer_pause : hint_range(0.0, 10.0) = 2.5;
// The colour the text briefly shifts toward — gold works on any text colour
uniform vec4 shimmer_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);

	// Total cycle length: pause + travel time
	float travel_time = 1.4 / shimmer_speed;
	float cycle = shimmer_pause + travel_time;

	// Where we are in the current cycle
	float t = mod(TIME, cycle);

	// shimmer_pos goes from -0.2 to 1.2 during the sweep, parked off-screen otherwise
	float shimmer_pos = -0.3;
	if (t > shimmer_pause) {
		shimmer_pos = -0.2 + (t - shimmer_pause) * shimmer_speed;
	}

	// Gaussian falloff centred on shimmer_pos
	float dist = UV.x - shimmer_pos;
	float shimmer = exp(-(dist * dist) / (shimmer_width * shimmer_width));

	// Only affect actual text pixels, not transparent background
	shimmer *= shimmer_strength * base_color.a;

	// mix() toward shimmer_color works on white, black, or any coloured text
	vec3 blended = mix(base_color.rgb, shimmer_color.rgb, shimmer);

	COLOR = vec4(blended, base_color.a);
}
