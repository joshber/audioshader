#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

// Processing-specific --
// _COLOR_ vs _TEXTURE_ according to whether we're using shader() or filter()
// (d.h., whether there's an underlying pixels[] to which we're applying a filter)
// With TEXTURE you get a builtin sampler called "texture"

#define PROCESSING_COLOR_SHADER
//#define PROCESSING_TEXTURE_SHADER

const float PI = 3.14159265359;

uniform vec2 resolution;

uniform float time; // milliseconds
uniform float frame;

// log-binned signal, left and right, up to .5 Nyquist frequency (with 44.1kHz sample rate that's 11kHz) 
uniform vec4 a, b;

void main( void ) {
	// Invert y-axis -- Processing y-axis runs top to bottom
	vec2 uv = vec2( gl_FragCoord.s / resolution.s, 1. - ( gl_FragCoord.t / resolution.t ) );

	// 1-texel offset for convolution filtering
	vec2 off = 1. / resolution; //vec2( 1. / resolution.s, 1. / resolution.t );

    vec3 col = vec3( 0. );

    // MAGIC
    
	gl_FragColor = vec4( col.rgb, 1. ) ;
}