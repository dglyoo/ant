$input a_position, a_texcoord0, a_texcoord1
$output v_texcoord0, v_texcoord1

#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));

    v_texcoord0 = a_texcoord0;
    v_texcoord1 = a_texcoord1;
}