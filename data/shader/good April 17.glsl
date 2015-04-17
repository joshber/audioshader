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
    vec2 uv0 = vec2( gl_FragCoord.s / resolution.s, 1. - ( gl_FragCoord.t / resolution.t ) ); // invert y-axis for Processing

    vec2 uv = 2. * uv0 - 1.; // [-1,1]

    vec2 off = 1. / resolution; // 1-texel offset for convolution filtering

    float c = 1.;

   // for ( float i = 0. ; i < 20. ; ++i ) {
        uv.t +=   /*mod( */sin(/* i  * */ 1./resolution.s * -.1 * PI * t  + pow( uv.s, 10. /*1. * sin( mod( t, 100. ) ) */ ) + uv.x); //, uv.y );
uv.s +=   /*mod( */sin(/* i  * */ 1./resolution.t * -.1 * PI * t  + pow( uv.t, 10. /*1. * sin( mod( t, 100. ) ) */ ) + uv.y);
        c = abs(1./uv.s) *  .1  * b.z;//.001 *  b.z ;// * a.x;
    //}
    c = 1. - c;
    gl_FragColor = vec4( uv0.s, 1. - uv0.t, c, 1. ) ;
}