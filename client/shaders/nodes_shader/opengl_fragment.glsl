#extension GL_ARB_gpu_shader5 : enable
uniform sampler2D baseTexture;

uniform vec4 skyBgColor;
uniform float fogDistance;
uniform vec3 eyePosition;
uniform vec2 vScreen;

uniform mat4 mInvWorldViewProj;

// The cameraOffset is the current center of the visible world.
uniform vec3 cameraOffset;
uniform float animationTimer;
#ifdef ENABLE_DYNAMIC_SHADOWS
	// shadow texture
	uniform sampler2D ShadowMapSampler;
	//shadow uniforms
	uniform mat4 mShadowWorldViewProj0;
	uniform mat4 mShadowWorldViewProj1;
	uniform mat4 mShadowWorldViewProj2;
	uniform vec4 mShadowCsmSplits;
	uniform vec3 v_LightDirection;
	uniform float f_textureresolution;
	uniform float f_brightness;
	uniform mat4 mWorldView;
	uniform mat4 mWorldViewProj;
	uniform mat4 m_worldView;
	uniform mat4 mWorld;

	uniform mat4 mShadowProj;
	uniform mat4 mShadowView;
	uniform mat4 mInvProj;
	uniform mat4 mInvWorldView;


	uniform vec3 vCamPos;

	varying vec4 P;
	varying vec3 N;
#endif

varying vec3 vPosition;
// World position in the visible world (i.e. relative to the cameraOffset.)
// This can be used for many shader effects without loss of precision.
// If the absolute position is required it can be calculated with
// cameraOffset + worldPosition (for large coordinates the limits of float
// precision must be considered).
varying vec3 worldPosition;
varying lowp vec4 varColor;
#ifdef GL_ES
varying mediump vec2 varTexCoord;
#else
centroid varying vec2 varTexCoord;
#endif
varying vec3 eyeVec;

const float fogStart = FOG_START;
const float fogShadingParameter = 1.0 / ( 1.0 - fogStart);


#ifdef ENABLE_DYNAMIC_SHADOWS



	vec3 rgb2hsl( in vec4 c )
	{
	    const float epsilon = 0.00000001;
	    float cmin = min( c.r, min( c.g, c.b ) );
	    float cmax = max( c.r, max( c.g, c.b ) );
	    float cd   = cmax - cmin;
	    vec3 hsl = vec3(0.0);
	    hsl.z = (cmax + cmin) / 2.0;
	    hsl.y = mix(cd / (cmax + cmin + epsilon), cd / (epsilon + 2.0 - (cmax + cmin)), step(0.5, hsl.z));

	    vec3 a = vec3(1.0 - step(epsilon, abs(cmax - c)));
	    a = mix(vec3(a.x, 0.0, a.z), a, step(0.5, 2.0 - a.x - a.y));
	    a = mix(vec3(a.x, a.y, 0.0), a, step(0.5, 2.0 - a.x - a.z));
	    a = mix(vec3(a.x, a.y, 0.0), a, step(0.5, 2.0 - a.y - a.z));
	    
	    hsl.x = dot( vec3(0.0, 2.0, 4.0) + ((c.gbr - c.brg) / (epsilon + cd)), a );
	    hsl.x = (hsl.x + (1.0 - step(0.0, hsl.x) ) * 6.0 ) / 6.0;
	    return hsl;
	}

	float getLinearDepth(in float depth) {
	  float near=0.1;
	  float far =20000.0;
	  return 2.0f * near * far / (far + near - (2.0f * depth - 1.0f) * (far - near));
	}

	 


	vec2 poissonDisk[4] = vec2[](
	  vec2( -0.94201624, -0.39906216 ),
	  vec2( 0.94558609, -0.76890725 ),
	  vec2( -0.094184101, -0.92938870 ),
	  vec2( 0.34495938, 0.29387760 )
	);
	vec2 offsetArray[16]=vec2[](
		 vec2(0.0, 0.0),
	     vec2(0.0, 1.0),
	     vec2(1.0, 0.0),
	     vec2(1.0, 1.0),
	     vec2(-2.0, 0.0),
	     vec2(0.0, -2.0),
	     vec2(2.0, -2.0),
	     vec2(-2.0, 2.0),
	     vec2(3.0, 0.0),
	     vec2(0.0, 3.0),
	     vec2(3.0, 3.0),
	     vec2(-3.0, -3.0),
	     vec2(-4.0, 0.0),
	     vec2(0.0, -4.0),
	     vec2(4.0, -4.0),
	     vec2(-4.0, 4.0));
	
	float getShadow(sampler2D shadowsampler, vec2 smTexCoord, float realDistance ,int cIdx) {
	     
		float nsamples=16.0;
	    float visibility=0.0;

	    
	    
	    for (int i = 0; i < nsamples; i++){
	        vec2 clampedpos = smTexCoord.xy + (offsetArray[i] /vec2(f_textureresolution));

	        //clampedpos=clamp(clampedpos.xy, vec2(0.0, 0.0), vec2(1.0, 1.0));   
	        float texDepth = texture2D( shadowsampler, clampedpos.xy )[cIdx];      
	        if (   realDistance   >  texDepth  ){
	            visibility += 1.0 ;
	        }        
	        
	    }
	    
	    return  visibility / nsamples ;
	}




	vec4 getDistortFactor(in vec4 shadowPosition) {
		
	  const float bias0 = 0.9f;
	  const float bias1 = 1.0f - bias0;

	  float factorDistance =  sqrt(shadowPosition.x * shadowPosition.x +
	  							   shadowPosition.y * shadowPosition.y );
	  //float factorDistance =  length(shadowPosition.xy);
	  float distortFactor = factorDistance * bias0 + bias1;

	    shadowPosition.xyz *= vec3(vec2(1.0 / distortFactor), .75);

	  return shadowPosition;
	}

	vec4 getDistortFactorv2(in vec4 shadowPosition) {
	  const float DistortPower = 7.0f;
	  const float SHADOW_MAP_BIAS = 0.9f;
	  vec2 p=shadowPosition.xy;
	  p = abs(p);
	  p = p * p * p;
	  float distordLengh=pow(p.x + p.y, 1.0f / 3.0f);
	  float len = 1e-6 + distordLengh;
	  distordLengh =  (1.0f - SHADOW_MAP_BIAS) + len * SHADOW_MAP_BIAS;
	  vec2 distortedcoords =  shadowPosition.xy / min(distordLengh, 1.0f);

	  return vec4(distortedcoords.xy,shadowPosition.z * 0.2,1.0);
	}

	vec3 getShadowSpacePosition(in vec4 pos,in mat4 shadowMVP) {

	  vec4 positionShadowSpace = mShadowProj* mShadowView * mWorld * pos; 
	  positionShadowSpace = getDistortFactor(positionShadowSpace);
	  positionShadowSpace.xy = positionShadowSpace.xy*0.5 +0.5;
	  positionShadowSpace.z = getLinearDepth(positionShadowSpace.z);
	  positionShadowSpace.z = positionShadowSpace.z*0.5 + 0.5;
	  return positionShadowSpace.xyz;
	}

	vec4 getWorldPosition(){
		vec4 positionNDCSpace = vec4(2.0f * gl_FragCoord.xy - 1.0f,
									 2.0f * gl_FragCoord.z - 1.0f,
									 1.0f);

		positionNDCSpace = vec4(
	        (gl_FragCoord.x / vScreen[0] - 0.5) * 2.0,
	        (gl_FragCoord.y / vScreen[1] - 0.5) * 2.0,
	        (gl_FragCoord.z - 0.5) * 2.0,
	        1.0);

	  vec4 positionCameraSpace = mInvProj * positionNDCSpace;

	  positionCameraSpace = positionCameraSpace / positionCameraSpace.w;

	  vec4 positionWorldSpace = mInvWorldView * positionCameraSpace;

	  return positionWorldSpace;

	}




	float getShadowv2(sampler2D shadowsampler, vec2 smTexCoord, float realDistance ,int cIdx) {
	    float texDepth = texture2D(shadowsampler, smTexCoord.xy )[cIdx];
		  //return step(texDepth-realDistance, 0.000005f * getLinearDepth(realDistance) + 0.00005f);

	    return ( realDistance  >  texDepth  ) ?  1.0  :0.0 ;
	}
	 

#endif


#ifdef ENABLE_TONE_MAPPING

/* Hable's UC2 Tone mapping parameters
	A = 0.22;
	B = 0.30;
	C = 0.10;
	D = 0.20;
	E = 0.01;
	F = 0.30;
	W = 11.2;
	equation used:  ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F
*/

vec3 uncharted2Tonemap(vec3 x)
{
	return ((x * (0.22 * x + 0.03) + 0.002) / (x * (0.22 * x + 0.3) + 0.06)) - 0.03333;
}

vec4 applyToneMapping(vec4 color)
{
	color = vec4(pow(color.rgb, vec3(2.2)), color.a);
	const float gamma = 1.6;
	const float exposureBias = 5.5;
	color.rgb = uncharted2Tonemap(exposureBias * color.rgb);
	// Precalculated white_scale from
	//vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
	vec3 whiteScale = vec3(1.036015346);
	color.rgb *= whiteScale;
	return vec4(pow(color.rgb, vec3(1.0 / gamma)), color.a);
}
#endif


void main(void)
{
	vec3 color;
	vec2 uv = varTexCoord.st;

	vec4 base = texture2D(baseTexture, uv).rgba;
#ifdef USE_DISCARD
	// If alpha is zero, we can just discard the pixel. This fixes transparency
	// on GPUs like GC7000L, where GL_ALPHA_TEST is not implemented in mesa,
	// and also on GLES 2, where GL_ALPHA_TEST is missing entirely.
	if (base.a == 0.0) {
		discard;
	}
#endif

	color = base.rgb;

	vec4 col = vec4(color.rgb * varColor.rgb, 1.0);


#if ENABLE_DYNAMIC_SHADOWS && DRAW_TYPE!=NDT_TORCHLIKE
		float shadow_int =0.0;
		
		float diffuseLight = dot(normalize(-v_LightDirection),normalize(N)) ;

		 

	    float bias = max(0.0005 * (1.0 - diffuseLight), 0.000005) ;  
	     
	    float NormalOffsetScale= 2.0+2.0/f_textureresolution;
	    float SlopeScale = abs(1-diffuseLight);
		NormalOffsetScale*=SlopeScale;
	    vec3 posNormalbias = P.xyz + N.xyz*NormalOffsetScale;
		diffuseLight=clamp(diffuseLight+0.2,0.5,1.0);
		float shadow_int0 =0.0;
		float shadow_int1 =0.0;
		float shadow_int2 =0.0;

		//float brightness = rgb2hsl(col).b;//(col.r+col.g+col.b)/3.0;
		
		

   		bias =  0.0000005 ;
 		//bias=0.0f;
        
        if(dot(normalize(-v_LightDirection),normalize(N))  <= 0){
        	shadow_int0=1.0f;
        }
		else {
			vec4 posInWorld = getWorldPosition() ;
			vec3 posInShadow=getShadowSpacePosition( posInWorld ,mShadowWorldViewProj0);
			if(posInShadow.x>0.0&&posInShadow.x<1.0&&posInShadow.y>0.0&&posInShadow.y<1.0)
			{
				bias = 1.0 - clamp(dot(normalize(N), posInShadow.xyz), 0.0, 1.0);
				bias = 0.0000000200 + 0.00000002 * bias;
				shadow_int0=getShadow(ShadowMapSampler, posInShadow.xy,
										posInShadow.z  + bias ,0);
			}
		}

		 
		shadow_int = shadow_int0;
		//shadow_int -= brightness;
		shadow_int *= 0.125;
		
		
		//ccol[cIdx]=0.15;
		 diffuseLight=1.0;
		col = clamp(vec4((col.rgb-shadow_int),col.a),0.0,1.0);
	#endif


	
 

#ifdef ENABLE_TONE_MAPPING
	col = applyToneMapping(col);
#endif

	// Due to a bug in some (older ?) graphics stacks (possibly in the glsl compiler ?),
	// the fog will only be rendered correctly if the last operation before the
	// clamp() is an addition. Else, the clamp() seems to be ignored.
	// E.g. the following won't work:
	//      float clarity = clamp(fogShadingParameter
	//		* (fogDistance - length(eyeVec)) / fogDistance), 0.0, 1.0);
	// As additions usually come for free following a multiplication, the new formula
	// should be more efficient as well.
	// Note: clarity = (1 - fogginess)
	float clarity = clamp(fogShadingParameter
		- fogShadingParameter * length(eyeVec) / fogDistance, 0.0, 1.0);
	col = mix(skyBgColor, col, clarity);
	col = vec4(col.rgb, base.a);

	gl_FragColor = col;
}
