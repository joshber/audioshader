// Longer-term TODO: Read source from interim save file with caret metadata, show the editing quasi-live

import ddf.minim.*;
import ddf.minim.analysis.*; // for FFT

Minim minim;
AudioInput input;
ShaderPipe pipe;

PShader shadr;

boolean displaySource = false;
boolean displaySpectrum = false;
boolean record = false;
PFont srcFont, specFont;
float srcFontSize = 14.;
float specFontSize = 10.;

String[] src;

void setup() {
    size( 1280, 720, P2D );
    frameRate( 60 );
    colorMode( RGB, 1.0 );
    
    // Set up audio listener
    minim = new Minim( this );
    input = minim.getLineIn();
    pipe = new ShaderPipe();
    input.addListener( pipe );
    
    refresh(); // load shader and configuration, if any
    
    shadr.set( "resolution", float( width ), float( height ) );

    // Zero out signal uniforms
    shadr.set( "a", 0., 0., 0., 0. );
    shadr.set( "b", 0., 0., 0., 0. );
    
    // For showing source and spectrum
    srcFont = createFont( "fonts/InputSans-Regular", srcFontSize, true /*antialiasing*/ );
    specFont = createFont( "fonts/InputSansNarrow-Regular", specFontSize, true );
    textAlign( LEFT, TOP );
    noStroke();
}
    
void draw() {
    background( 0. );
    
    // float() bc GLSL < 3.0 can't do modulo on int
    shadr.set( "time", float( millis() ) );
    shadr.set( "frame", float( frameCount ) );

    pipe.passthru(); // pass the signal

    // Blink and you'll miss it
    shader( shadr );
    rect( 0, 0, width, height );

    resetShader();
    
    if ( displaySpectrum )
        pipe.drawSpectrum();

    if ( displaySource || record )
        src = loadStrings( "shader/shader.glsl" );

    if ( displaySource ) {
        pushStyle();
        
        // Background scrim and text color
        fill( 1., 1., 1., .67 );
        rect( 0, 0, width / 2, height );
        fill( 0 ); // text color
        
        textFont( srcFont );
        textSize( srcFontSize );

        int i;
        for ( i = 0; i < src.length && ! src[i].startsWith( "void main" ) ; ++i ) ;

        for ( int j = 1 ; i < src.length && 1.5 * ( j + 1 ) < height ; ++i, ++j ) {
            text( src[i], srcFontSize * 1.5, srcFontSize * 1.5 * j );
        }

        // "Recording" indicator
        if ( record ) {
            fill( 1., 0., 0., 1. );
            text( String.format( "Recording ... Frame %06d", frameCount ), srcFontSize * 1.5, height - 1.5 * srcFontSize );
        }
        
        popStyle();
    }

    // Save the frame and the shader (no synchronization, always a chance of slippage)
    if ( record ) {
        saveFrame( "data/out/frames/######.jpg" );
        saveStrings( String.format( "data/out/shaders/%06d.glsl", frameCount ), src );
    }
}

void refresh() {
    shadr = loadShader( "shader/shader.glsl" );
}

void stop() {
    input.close();
    minim.stop();
    
    super.stop();
}

void keyPressed() {
    if ( key == 'r' || key == 'R' ) {
        refresh();
    }
    else if ( key == 's' || key == 'S' ) {
        displaySource = displaySource ? false : true;
    }
    else if ( key == '%' ) {
        displaySpectrum = displaySpectrum ? false : true;
    }
    else if ( key == '*' ) {
        record = record ? false : true;
    }
}

class ShaderPipe implements AudioListener {
    private float[] left, right;

    private FFT fft;

    ShaderPipe() {
        right = left = null;

        fft = new FFT( input.bufferSize(), input.sampleRate() );
        fft.logAverages( int( input.sampleRate() ) <<5 /*minimum bandwidth*/, 1 /*bands per octave*/ );
            // <<5 == /32 -- 5 bands total up to Nyquist frequency
            // If sample rate == 44.1kHz, first four bands cover up to 11kHz
            // We can tune this for greater sensitivity in the low range, i.e. drop minimum to <<6 or <<7
    }
      
    synchronized void samples( float[] s ) {
        left = s;
    }
    synchronized void samples( float[] l, float[] r ) {
        left = l;
        right = r;
    }
    
    synchronized void passthru() {
        // Two uniform vec4 -- a for left, b for right
        
        // if left==null, i.e., no signal, just send the most recently obtained spectrum
        // The frozen screen is more informative about what went wrong and when than a blank
        
        if ( left != null ) {
            fft.forward( left );
            shadr.set( "a", fft.getBand( 0 ), fft.getBand( 1 ), fft.getBand( 2 ), fft.getBand( 3 ) );
        }
        // if right==null, i.e., mono signal, b gets the same values as a
        if ( right != null ) {
            fft.forward( right );
        }
        shadr.set( "b", fft.getBand( 0 ), fft.getBand( 1 ), fft.getBand( 2 ), fft.getBand( 3 ) );
    }
    
    synchronized void drawSpectrum() {
        pushStyle();
        
        // Background scrim and text color
        fill( 0., 0., 0., .67 );
        //rect( width - x, height - y, x, y );
        //fill( 0 ); // text color TODO

        textFont( specFont );
        textSize( specFontSize );
        
        // TODO
        
        popStyle();
    }
}
