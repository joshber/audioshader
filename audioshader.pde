// KEY TODO: Implement stream.mov

// Longer-term TODO: Connect to editor with an IPC pipe, show editing live

import ddf.minim.*;
import ddf.minim.analysis.*; // for FFT

Minim minim;
AudioInput input;
ShaderPipe pipe;

PShader shadr;

boolean displaySource = false;
boolean displaySpectrum = false;
boolean record = false;

PFont srcFont; //, specFont;
float srcFontSize = 12.;
//float specFontSize = 10.;

String[] src, src0;
int[] diffs;

final String shaderPath = "shader/shader.glsl";


void setup() {
    size( 1280, 720, P2D );
    frameRate( 60 );
    colorMode( RGB, 1.0 );
    
    // Set up audio listener
    minim = new Minim( this );
    input = minim.getLineIn();
    pipe = new ShaderPipe();
    input.addListener( pipe );
    
    // For highlighting source diffs
    src = loadStrings( shaderPath );
    diffs = new int[200];
    for ( int i = 0; i < 200; ++i )
        diffs[i] = 0;
        
    refresh(); // load shader and configuration, if any
    
    // For showing source and spectrum
    srcFont = createFont( "fonts/InputSansNarrow-Regular", srcFontSize, true /*antialiasing*/ );
    //specFont = createFont( "fonts/InputSansNarrow-Regular", specFontSize, true );
    textAlign( LEFT, TOP );
    noStroke();    
}
    
void draw() {
    background( 0. );
    
    // Twice a second, check for an updated shader
    if ( frameCount % 30 == 0 )
        refresh();
    
    // float() bc GLSL < 3.0 can't do modulo on int
    shadr.set( "t", float( millis() ) );
    shadr.set( "f", float( frameCount ) );

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
                
        // Background scrim
        fill( 1., 1., 1., .67 );
        rect( 0, 0, width / 2, height );
        
        textFont( srcFont );
        textSize( srcFontSize );
        fill( 0. ); // text color TODO

        int i, j;
        for ( i = 0; i < src.length && ! src[i].startsWith( "void main" ) ; ++i ) ;
        for ( j = 0; j < src0.length && ! src[j].startsWith( "void main" ) ; ++j ) ;

        for ( int k = 1 ; i < src.length && 1.5 * ( k + 2 ) < height ; ++i, ++k ) {
            // if corresponding lines of the shader file, counting from start of main(),
            // differ between current source and diffs baseline, reset the diffs counter for this line
            if ( i < diffs.length && ! src[i].equals( src0[j++] ) ) {
                diffs[i] = 1800; // 1800 frames == c.30s
            }
            // diffs highlighting fades over 1800 frames (c.30s) from most recent diff on this line
            if ( diffs[i] > 0 ) {
                //println( String.format( "%02d %04d", i, diffs[i] ) ); 
                pushStyle();
                fill( 1., 1., 1., .33 / 1800. * diffs[i] );
                rect( 0, 1.5 * k * srcFontSize, width / 2, 1.5 * srcFontSize );
                popStyle();                
                --diffs[i];
            }
            
            text( src[i], 1.5 * srcFontSize, 1.5 * k * srcFontSize );
        }

        // "Recording" indicator
        if ( record ) {
            fill( 1., 0., 0., 1. );
            rect( 0, height - 2. * srcFontSize, width / 2, 1.5 * srcFontSize );
            fill( 1., 1., 1., 1. );
            text( String.format( "Recording: Frame %06d", frameCount ), srcFontSize * 1.5, height - 2. * srcFontSize );
        }
        
        popStyle();
    }

    // Save the frame and the shader (no synchronization, always a chance of slippage)
    if ( record ) {
        String path = String.format( "data/out/%04d-%02d-%02d/", year(), month(), day() );
        saveFrame( path + "frames/######.jpg" );
        saveStrings( path + String.format( "shaders/%06d.glsl", frameCount ), src );
    }
}

// comparing last-modified dates using Java Nio proved gross,
// so we simply reload and re-baseline diffs every so many frames
void refresh() {
    shadr = loadShader( shaderPath );
    
    shadr.set( "resolution", float( width ), float( height ) );
        
    src0 = src; // update diffs baseline
}

void stop() {
    input.close();
    minim.stop();
    
    super.stop();
}

void keyPressed() {
    if ( key == 's' || key == 'S' ) {
        displaySource = displaySource ? false : true;
    }
    else if ( key == '%' ) {
        displaySpectrum = displaySpectrum ? false : true;
    }
    else if ( key == '*' ) {
        record = record ? false : true;
    }
    else if ( key == 'r' || key == 'R' ) {
        refresh();
    }
}

class ShaderPipe implements AudioListener {
    private float[] left, right;

    private FFT fft;
    private int binOffset;

    ShaderPipe() {
        right = left = null;

        fft = new FFT( input.bufferSize(), input.sampleRate() );
        fft.logAverages( int( input.sampleRate() ) >>6 /*minimum bandwidth*/, 1 /*bands per octave*/ );
            // >>6 == /64 -- 6 bins total up to Nyquist frequency, bin 0 goes up to 689Hz
            // We can tune this for greater sensitivity in the low or high range, i.e. shift minimum between >>4 and >>9

        binOffset = 0; // send the lowest four bins
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
        // TODO scale a, b to [0,1]
        
        if ( left != null ) {
            fft.forward( left );
            shadr.set( "a", fft.getAvg( binOffset + 0 ), fft.getAvg( binOffset + 1 ), fft.getAvg( binOffset + 2 ), fft.getAvg( binOffset + 3 ) );
            // if right==null, i.e., mono signal, b gets the same values as a
            if ( right != null ) {
                fft.forward( right );
            }
            shadr.set( "b", fft.getAvg( binOffset + 0 ), fft.getAvg( binOffset + 1 ), fft.getAvg( binOffset + 2 ), fft.getAvg( binOffset + 3 ) );
        }
        else {
            shadr.set( "a", 0., 0., 0., 0. );
            shadr.set( "b", 0., 0., 0., 0. );
        }
    }
    
    synchronized void drawSpectrum() {
        pushStyle();
        
        float binWidth = 20.;
        float gutter = 2.;
        float hEdge = width - ( 2. * fft.avgSize() + 3. ) * ( binWidth + gutter );
            // 2 channels + 1 left/right margin + 1 channel gutter
        
        float scale = 50.; // make the signal more visible

        // Background scrim
        fill( 1., 1., 1., .67 );
        rect( hEdge, 0, width - hEdge, height );

        if ( left != null ) {
            fft.forward( left );
            for ( int i = 0; i < fft.avgSize(); ++i ) {
                fill( i >= binOffset && i < binOffset + 4 ? 1. : 0., .33 ); // gray out bins not sent to the shader
                rect(   hEdge + ( i + 1. ) * ( binWidth + gutter ), height - 1.5 * srcFontSize - fft.getAvg( i ) * scale,
                        binWidth, fft.getAvg( i ) * scale );
            }
        }    
        if ( right != null ) {
            fft.forward( right );
            hEdge += ( fft.avgSize() + 1. ) * ( binWidth + gutter );
            for ( int i = 0; i < fft.avgSize(); ++i ) {
                fill( i >= binOffset && i < binOffset + 4 ? 1. : 0., .33 ); // gray out bins not sent to the shader
                rect(   hEdge + ( i + 1. ) * ( binWidth + gutter ), height - 1.5 * srcFontSize - fft.getAvg( i ) * scale,
                        binWidth, fft.getAvg( i ) * scale );
            }
        }    

        popStyle();
    }
}
