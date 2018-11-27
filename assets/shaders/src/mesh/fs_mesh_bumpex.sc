$input v_texcoord0, v_lightdir, v_viewdir, v_normal

#include <common.sh>
#include "common/lighting.sh"
#include "common/uniforms.sh"

SAMPLER2D(s_basecolor,  0);
SAMPLER2D(s_normal, 1);

SAMPLER2D(s_shadowMap0,4);

uniform vec4 u_specularColor;
uniform vec4 u_specularLight;

vec4 calc_lighting_BH(vec3 normal, vec3 lightdir, vec3 viewdir, 
						vec4 lightColor, vec4 diffuseColor, vec4 specularColor, 
						float gloss)
{
	float ndotl = max(0, dot(normal, lightdir));

	float hdotn = saturate(dot(normal,normalize(viewdir + lightdir)));
	float shininess = specularColor.w;   									 // spec shape
	float specularFactor = pow(hdotn, shininess * 128) * u_specularLight.x;  // spec intensity 

	vec3 diffuse = diffuseColor.xyz * lightColor.xyz * ndotl;
	vec3 specular = specularColor.rgb * specularFactor * gloss;              // gloss from normalmap texture 

	//return vec4(specularFactor * gloss, specularFactor * gloss, specularFactor * gloss, 1.0);
	//return vec4(specular,1.0);
	return vec4(diffuse + specular, 1.0);
}


// 可以统一加到 common 库，作为通用 ambient 函数
// normal must transfer to worldspace
vec4 get_ambient_color(float ambientMode,vec3 normal) 
{
	// gradient mode 
	if(ambientMode == 2.0) {
		float angle = normal.y;
		if(angle>0)
			return (ambient_skycolor*angle) + (ambient_midcolor*(1-angle));
		else {
			angle = - angle;
		    return (ambient_groundcolor*angle) + (ambient_midcolor*(1-angle));
		}
	    return ambient_midcolor;
	}

	// default classic mode 
	return ambient_skycolor;
}


void main()
{
	vec2 tc = vec2(v_texcoord0.x, v_texcoord0.y);

	vec4 ntexdata = texture2D(s_normal, tc);	
	vec3 normal = vec3(ntexdata.xy, 0.0);
	normal.xy = normal.xy * 2.0 - 1.0;
	normal.z = sqrt( (1.0- saturate(dot(normal.xy, normal.xy))) );
	float gloss = ntexdata.z;	

	// projection back 
	float pX = normal.x/(1.0 + normal.z);
	float pY = normal.y/(1.0 + normal.z);
	float denom = 2/(1.0 +pX*pX + pY*pY);
	normal.x = pX *denom;
	normal.y = pX *denom;
	normal.z = denom -1.0; 
	 

    // not need now,, not in linear space 
	// vec4 basecolor = toLinear(texture2D(s_basecolor, tc));   
	vec4 basecolor = texture2D(s_basecolor, tc);

	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	
	float ambientMode   = ambient_mode.x;
	float ambientFactor = ambient_mode.y;   // Factor not use
	vec4  ambientColor  = get_ambient_color( ambientMode, v_normal  ) ;
	ambientColor = ambientColor*basecolor;
    
	gl_FragColor = saturate(ambientColor + calc_lighting_BH(normal, v_lightdir, v_viewdir, lightcolor, basecolor, u_specularColor, gloss));

	//gl_FragColor = vec4(v_normal.xyz,1); //*0.5+0.5,1);
}