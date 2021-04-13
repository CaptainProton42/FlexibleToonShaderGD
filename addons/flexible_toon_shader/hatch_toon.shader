shader_type spatial;

//render_mode ambient_light_disabled;

const float PI = 3.1415926536f;

const mat2 ORIENTATION_STRAIGHT = mat2(vec2(1.0f, 0.0f), vec2(0.0f, 1.0f));
const mat2 ORIENTATION_CROSS = mat2(vec2(0.0f, 1.0f), vec2(1.0, 0.0f));

uniform vec4 albedo : hint_color = vec4(1.0f);
uniform sampler2D albedo_texture : hint_albedo;

uniform int cuts : hint_range(1, 8) = 2;
uniform float wrap : hint_range(-2.0f, 2.0f) = 0.0f;
uniform float steepness : hint_range(1.0f, 8.0f);

uniform bool use_attenuation = true;

uniform bool use_rim = false;
uniform float rim_width : hint_range(0.0f, 16.0f) = 8.0f;
uniform vec4 rim_color : hint_color = vec4(1.0f);

uniform float hatch_scale = 2.0f;
uniform bool use_triplanar = true;
uniform sampler2D hatch_texture : hint_albedo;

varying vec3 vertex_pos;
varying vec3 normal;

vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos, mat2 orientation) {
	p_weights = abs(p_weights);
	p_weights /= p_weights.x+p_weights.y+p_weights.z;
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,orientation*p_triplanar_pos.xy) * p_weights.z;
	samp+= texture(p_sampler,orientation*p_triplanar_pos.xz) * p_weights.y;
	samp+= texture(p_sampler,orientation*p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

float split_hatch(float diffuse, vec2 uv, vec3 weights, vec3 pos) {
	float value = 1.0f;
	float k = round((1.0f - diffuse) * float(cuts)) - 0.5;
	for (float i = 0.0f; i < k; ++i) {
		float offset = 2.0 * i / float(cuts);
		
		if (i >= float(cuts) / 2.0) {
			if (use_triplanar) {
				value *= triplanar_texture(hatch_texture, weights, pos + vec3(offset), ORIENTATION_CROSS).r;
			} else {
				value *= texture(hatch_texture, uv.yx + vec2(offset)).r;
			}
		} else {
			if (use_triplanar) {
				value *= triplanar_texture(hatch_texture, weights, pos + vec3(offset), ORIENTATION_STRAIGHT).r;
			} else {
				value *= texture(hatch_texture, uv.xy + vec2(offset)).r;
			}			
		}
		
	}
	return value;
}

void vertex() {
	vertex_pos = VERTEX;
	normal = NORMAL;
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
}

void light() {
	// Attenuation.
	float attenuation = 1.0f;
	if (use_attenuation) {
		attenuation = ATTENUATION.x;
	}
	
	// Diffuse lighting.
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (attenuation - 1.0) + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0f / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);
	
	// Apply diffuse result to different styles.
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	diffuse *= split_hatch(diffuse_stepped, hatch_scale*UV, normal, hatch_scale*vertex_pos);
	
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
	
	// Simple rim lighting.
	if (use_rim) {
		float NdotV = dot(NORMAL, VIEW);
		float rim_light = pow(1.0 - NdotV, rim_width);
		DIFFUSE_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
	}
}