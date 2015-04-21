// TODO: Record the signal (as fft) along with frame and source?

// Longer-term TODO: Connect to editor with an IPC pipe, show editing live -- or embed an editor?

import ddf.minim.*;
import ddf.minim.analysis.*; // for FFT

// To get configuration and UI parameters from the shader source
import java.util.regex.Pattern;
import java.util.regex.Matcher;

Minim minim;
AudioInput input;
ShaderPipe pipe;

PShader shadr;

boolean displaySource = true;
boolean displaySpectrum = true;
boolean record = false;
String recordLabel;

PFont srcFont;
float srcFontSize = 12.;

String[] src, src0;
int[] diffs;
int diffsFadeFrames = 300; // # frames to mark diff lines

final String shaderPath = "shader/shader.glsl";

boolean sketchFullScreen() {
    return false;
}

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
    srcFont = createFont( "fonts/InputSansCondensed-Black.ttf", srcFontSize, true /*antialiasing*/ );
    textAlign( LEFT, TOP );
    noStroke();
}
    
void draw() {
    background( 0. );
    
    // Twice a second, check for an updated shader
    if ( frameCount % 30 == 0 )
        refresh();
    
    shadr.set( "t", float( millis() ) ); // float() bc GLSL < 3.0 can't do modulo on int

    pipe.passthru(); // pass the signal

    // Blink and you'll miss it
    shader( shadr );
    rect( 0, 0, width, height );

    resetShader();
    
    if ( displaySource || record )
        src = loadStrings( "shader/shader.glsl" );

    if ( displaySource ) {
        pushStyle();
                
        // No background scrim: looks better without
        
        textFont( srcFont );
        textSize( srcFontSize );

        int i, j;
        for ( i = 0; i < src.length && ! src[i].startsWith( "void main" ) ; ++i ) ;
        for ( j = 0; j < src0.length && ! src[j].startsWith( "void main" ) ; ++j ) ;

        for ( int k = 1 ; i < src.length && 1.5 * ( k + 2 ) < height ; ++i, ++k ) {
            // if corresponding lines of the shader file, counting from start of main(),
            // differ between current source and diffs baseline, reset the diffs counter for this line
            if ( k < diffs.length && ! src[i].equals( src0[j++] ) ) {
                diffs[k] = diffsFadeFrames;
            }
            // diffs highlighting fades over diffsFadeFrames from most recent diff on this line
            if ( diffs[k] > 0 ) {
                pushStyle();
                fill( 1., 1., 0., .8 / diffsFadeFrames * diffs[k] );
                rect( 0, 1.5 * k * srcFontSize, width, 1.5 * srcFontSize );
                popStyle();                
                --diffs[k];
            }
            
            // Drop shadow
            translate( 1., 1. );
            fill( 0., .5 );
            text( src[i], 1.5 * srcFontSize, 1.5 * k * srcFontSize );
            translate( -1., -1. );

            fill( 1., 1. ); // text color
            text( src[i], 1.5 * srcFontSize, 1.5 * k * srcFontSize );
            
            // Show the recording indicator across the bottom
            // Goes here so we can record with no UI artifact by concealing source
            if ( record ) {
                pushStyle();
                fill( 1., 0., 0., 1. );
                rect( 0, height - 1., width, 2. );
                popStyle();
            }
        }
        
        popStyle();
    }
    
    if ( displaySpectrum )
        pipe.drawSpectrum();

    // Save the frame and the shader (no synchronization, always a chance of slippage)
    if ( record ) {
        String path = String.format( "data/out/%s/%04d-%02d-%02d/", recordLabel, year(), month(), day() );
        saveFrame( path + "frames/######.jpg" );
        saveStrings( path + String.format( "shaders/%06d.glsl", frameCount ), src );
    }
}

// comparing last-modified dates using Java Nio proved gross,
// so we simply reload and re-baseline diffs twice a second
void refresh() {
    shadr = loadShader( shaderPath );
    
    shadr.set( "res", float( width ), float( height ) );
        
    src0 = src; // update diffs baseline
    src = loadStrings( shaderPath );

    //
    // Check last line of source for configuration and UI parameters
    // ::sigh:: to think how concise this would be in Perl ...

    final Pattern dyRange = Pattern.compile( "fft (\\d){1,2} (\\d){1,2}" ); // fft n n
    final Pattern concealSource = Pattern.compile( "-source" );
    final Pattern concealSpectrum = Pattern.compile( "-spec" );
    final Pattern rec = Pattern.compile( "record ([^\\s]+)" );
    
    String config = src[src.length - 1];
    Matcher m;
    
    // fft <# bins> <offset>
    m = dyRange.matcher( config );
    if ( m.find() ) {
        pipe.updateAveraging( int( m.group( 1 ) ), int( m.group( 2 ) ) );
    }
    else
        pipe.resetAveraging();

    // -source
    m = concealSource.matcher( config );
    displaySource = m.find() ? false : true;
    
    // -spec
    m = concealSpectrum.matcher( config );
    displaySpectrum = m.find() ? false : true;
    
    // record <label>
    m = rec.matcher( config );
    if ( m.find() ) {
        record = true;
        recordLabel = m.group( 1 );
    }
    else
        record = false;
}

void stop() {
    input.close();
    minim.stop();
    
    super.stop();
}

class ShaderPipe implements AudioListener {
    private float[] left, right;

    private FFT fft;
    private int binOffset;

    ShaderPipe() {
        right = left = null;

        fft = new FFT( input.bufferSize(), input.sampleRate() );
        resetAveraging();
    }
    
    void updateAveraging( int nBins, int offset ) {
        fft.logAverages( int( input.sampleRate() ) >> nBins, 1 );
        binOffset = offset;
    }
    void resetAveraging() {
        fft.logAverages( int( input.sampleRate() ) >>6 /*minimum bandwidth*/, 1 /*bands per octave*/ );
            // >>6 == /64 -- 6 bins total up to Nyquist frequency, at 44.1KHz sampling bin 0 goes up to 689Hz
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
        
        float binWidth = 10.;
        float gutter = 2.;
        float hEdge = width - ( 2. * fft.avgSize() + 3. ) * ( binWidth + gutter );
            // 2 channels + 1 left/right margin + 1 channel gutter
        
        float scale = 50.; // make the signal more visible

        // Background scrim: looks better without

        if ( left != null ) {
            fft.forward( left );
            for ( int i = 0; i < fft.avgSize(); ++i ) {
                fill( 1., .2, 0., i >= binOffset && i < binOffset + 4 ? 1. : .5 ); // alpha out bins not sent to the shader
                rect(   hEdge + ( i + 1. ) * ( binWidth + gutter ), height - 1.5 * srcFontSize - fft.getAvg( i ) * scale,
                        binWidth, fft.getAvg( i ) * scale );
            }
        }    
        if ( right != null ) {
            fft.forward( right );
            hEdge += ( fft.avgSize() + 1. ) * ( binWidth + gutter );
            for ( int i = 0; i < fft.avgSize(); ++i ) {
                fill( 1., .2, 0., i >= binOffset && i < binOffset + 4 ? 1. : .5 ); // alpha out bins not sent to the shader
                rect(   hEdge + ( i + 1. ) * ( binWidth + gutter ), height - 1.5 * srcFontSize - fft.getAvg( i ) * scale,
                        binWidth, fft.getAvg( i ) * scale );
            }
        }    

        popStyle();
    }
}
