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

uniform float t; // time, milliseconds
uniform float f; // frame #

// log-binned signal, left and right, up to .5 Nyquist frequency (with 44.1kHz sample rate that's 11kHz) 
uniform vec4 a, b;

// TODO
// rand, gaussian, lognormal, fns for noise (simplex), distortion (as with Zeitgeber), horizontal and vertical blur, brightness enhancement

void main( void ) {
    vec2 uv = vec2( gl_FragCoord.s / resolution.s, 1. - ( gl_FragCoord.t / resolution.t ) ); // invert y-axis for Processing

    uv = 2. * uv - 1.; // [-1,1]

    vec2 off = 1. / resolution; // 1-texel offset for convolution filtering

    float c = 0.;
    
//    uv.x = .5 * ( 1. + sin( mod(t, 100.) * uv.y ) );
    uv.s +=  .35 * sin( 1./resolution.t * 1.*PI * t * .05*mod(f,10.) * uv.t + uv.t);
    
    c = .1*abs(1./uv.x) * .1* b.z * a.z;
//    c = abs(sin( f * b.w ) + cos( t * uv.y ) * a.x * b.z * .3 ); 
/*    uv.x = abs( sin( t * uv.y ) ) * b.y;
    c = 1.5 * uv.y * cos( PI * ( .3 - abs(  - uv.x ) ) ) * ( a.y + b.z );
    
  */  
    gl_FragColor = vec4( c, c, c, 1. ) ;
}