/* TODO
 - Integrate Most Pixels Ever
    - Validator
    - Test the boolean[] approach to flagging validation errors?
 - Include a line # in errorLineNos no more than once? (right now, multiples for multiple errors on a single line)
*/

/*
 * audioshader -- Audio-driven live procedural video directly on the graphics layer
 * Josh Berson jbrs@eml.cc, 2015
 * MIT License
 * Inspired by rob @hexler. Special thanks to Luca Mortellaro and Rohini Devasher
 */

// Most Pixels Ever -- treat multiple displays as a single viewport
// https://github.com/shiffman/Most-Pixels-Ever-Processing/wiki/Processing-Tutorial
import mpe.client.*;

// Audio sampling
import ddf.minim.*;
import ddf.minim.analysis.*; // for FFT

// To get configuration and UI parameters from the shader source, check ESSL validator output for errors 
import java.util.regex.Pattern;
import java.util.regex.Matcher;

import java.io.*; // to run ESSL validator externally, see validateShader()

TCPClient mpeSub;

Minim minim;
AudioInput input;
ShaderPipe pipe;

PShader shadr;
int lastRefreshTime = 0;

boolean displaySource = true;
boolean displaySpectrum = true;
boolean record = false;
String recordLabel;

PFont srcFont;
float srcFontSize = 12.;

String[] src, src0;
int[] diffs;
String errorLineNos;
int diffsFadeFrames = 300; // # frames to mark diff lines

final String shaderPath = "shader/shader.glsl";
final String validatorPath = "shader/essl_to_glsl_osx";

boolean sketchFullScreen() {
    return false;
}

/*
 * MPE version
 *
TODO for multiple-host version:
- Designate one host the listener, have it distribute FFT to the others
- Ensure shared endpoint for the shader
- Do we need to send a single value for t to all instances of the shader?
  Maybe millis() from the listener?
- What to do about recording mode? Maybe designate a recorder,
  have it save jpegs for the whole rendered rect ?
- Tweak frame rate and source diffs fade rate
- Subsitute mpeSub.getMWidth() and getMHeight() for width and height -- see wrapper fns below

// Supercedes setup() under Most Pixels Ever
// -- called whenever a new subscriber connects
public void resetEvent( TCPClient sub ) {
    frameRate( 60 );
    colorMode( RGB, 1.0 );

    // etc
}

// Supercedes draw() under Most Pixels Ever
// -- called whenever the subscriber receives a "Draw next frame" message from the server
void frameEvent( TCPClient sub ) {
    // Strategy: Each host renders the whole scene, then uses translate() to show just its part
    // So the shader gets the master dimensions
    // And each host renders the whole overlay
}

void draw() { } // Needed even though it's empty
*/

// Wrappers to facilitate switching to multiple-hosts version
int getWidth() {
    return width;
    //return mpeSub.getMWidth();
}
int getHeight() {
    return height;
    //return mpeSub.getMHeight();
}

void setup() {
/*
    // Set up Most Pixels Ever
    mpeSub = new TCPClient( this, "mpe/mpe.xml" );
    
    // Local display dimensions
    size( mpeSub.getLWidth(), mpeSub.getLHeight() );
    
    resetEvent( mpeSub );
    mpeSub.start();
*/

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
    srcFont = createFont( "fonts/SourceCodePro-Bold.otf", srcFontSize, true ); // true==antialiasing
    textAlign( LEFT, TOP );
    noStroke();
}

void draw() {
    background( 0. );

    // Twice a second, check for an updated shader
    int t = millis();
    if ( t - lastRefreshTime > 490 ) {
        refresh();
        lastRefreshTime = t;
    }
    
    shadr.set( "t", float( t ) ); // float() bc ESSL can't do modulo on int (GLSL < 3.0)

    pipe.passthru(); // pass the signal

    // Blink and you'll miss it
    shader( shadr );
    rect( 0, 0, width, height );
        // Here width and height need to be local, even in multiple-hosts mode
        // GPU renders the whole scene, then we'd translate to display one section

    resetShader();
    
    if ( displaySource || record )
        src = loadStrings( "shader/shader.glsl" );

    // Save the frame and the shader (no synchronization, always a chance of slippage)
    // We do this here so there's no UI artifact in the frame (proved less than useful)
    if ( record ) {
        String path = String.format( "data/out/%s/%04d-%02d-%02d/", recordLabel, year(), month(), day() );
        saveFrame( path + "frames/######.jpg" );
        saveStrings( path + String.format( "shaders/%06d.glsl", frameCount ), src );
    }
    
    if ( displaySpectrum )
        pipe.drawSpectrum();

    if ( displaySource )
        drawSource();
}

void stop() {
    input.close();
    minim.stop();
    
    super.stop();
}

// comparing last-modified dates using Java Nio proved gross,
// so we simply reload and re-baseline diffs twice a second
void refresh() {
    src0 = src; // update diffs baseline
    src = loadStrings( shaderPath );

    //
    // UI note:
    // If the shader does not validate, show the nonvalidating one (with erroneous lines marked)
    // but continue running the existing one
    // So update src0 and src first, but wait to call loadShader()

    if ( ! validateShader() ) return;

    shadr = loadShader( shaderPath );
    
    shadr.set( "res", float( getWidth() ), float( getHeight() ) );

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

boolean validateShader() {
    final String cmd = dataPath( "" ) + "/" + validatorPath + " " + dataPath( "" ) + "/" + shaderPath;
    boolean rc = true;
    try {
        Runtime rt = Runtime.getRuntime();
        Process p = rt.exec( cmd );
        
        BufferedReader errors = new BufferedReader( new InputStreamReader( p.getInputStream() ) );
        
        // For ideas see
        // https://github.com/felixpalmer/glsl-validator/blob/master/glsl-validate.py
        // https://github.com/WebGLTools/GL-Shader-Validator/blob/master/GLShaderValidator.py
        // ^^ nice regex parsing of Angle output, starting line 85
        
        final Pattern errorNotice = Pattern.compile( "ERROR: 0:(\\d+)" );
        Matcher m;
        
        String l;
        errorLineNos = "";
        
        while ( ( l = errors.readLine() ) != null ) {
            // For the time being, we're not flagging erroneous tokens in the displayed source,
            // just noting whether a line had an error
            
            m = errorNotice.matcher( l );
            if ( m.find() ) {
                errorLineNos += m.group( 1 ).toString() + " ";
                rc = false; // Did not validate
            }
        }   
    }
    catch ( Exception e ) {
        println( e.toString() );
        //e.printStackTrace();
    }
    return rc;
}

void drawSource() {
    pushStyle();
                
    // No background scrim: looks better without
        
    textFont( srcFont );
    textSize( srcFontSize );

    int i, j;
    for ( i = 0; i < src.length && ! src[i].startsWith( "void main" ) ; ++i ) ;
    for ( j = 0; j < src0.length && ! src[j].startsWith( "void main" ) ; ++j ) ;

    boolean errorDisplayed = false;
    
    for ( int k = 1 ; i < src.length && 1.5 * ( k + 2 ) < getHeight() ; ++i, ++k ) {
        // if corresponding lines of the shader file, counting from start of main(),
        // differ between current source and diffs baseline, reset the diffs counter for this line
        if ( k < diffs.length && ! src[i].equals( src0[j++] ) ) {
            diffs[k] = diffsFadeFrames;
        }
        
        // Highlight lines with errors, searching errorLineNos for a match to i+1
        // If there are any errors but they're not found here, must be above /^void main(/
        // so put a red bar at the top of the source display
        // This approach won't catch the case where there are errors above main()
        // as WELL as within, but that's fine -- focal case is live editing of main()
        if ( errorLineNos.contains( Integer.toString( i + 1 ) + " " ) ) {
            pushStyle();
            fill( 1., 0., 0., .5 );
            rect( 0, 1.5 * k * srcFontSize, getWidth(), 1.5 * srcFontSize );
            popStyle();
            errorDisplayed = true;
        }
        
        // diffs highlighting fades over diffsFadeFrames from most recent diff on this line
        // -- don't show diffs if the line has an error, just maintain the red
        else if ( diffs[k] > 0 ) {
            pushStyle();
            fill( 1., 1., 0., .8 / diffsFadeFrames * diffs[k] );
            rect( 0, 1.5 * k * srcFontSize, getWidth(), 1.5 * srcFontSize );
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
    }
    
    // If the shader did not validate but there are no errors in main(),
    // indicate that the problem comes earlier in the shader
    if ( ! errorLineNos.equals( "" ) && errorDisplayed == false ) {
        fill( 1., 0., 0., .5 );
        rect( 0, 0, getWidth(), 1.5 * srcFontSize );
    }
    
    // Show the recording indicator across the bottom
    // Goes here so we can record silently by concealing source
    if ( record ) {
        fill( 1., 0., 0., 1. );
        rect( 0, getHeight() - 1., getWidth(), 2. );
    }
        
    popStyle();
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
            shadr.set(  "a",
                        fft.getAvg( binOffset + 0 ), fft.getAvg( binOffset + 1 ),
                        fft.getAvg( binOffset + 2 ), fft.getAvg( binOffset + 3 ) );
            // if right==null, i.e., mono signal, b gets the same values as a
            if ( right != null ) {
                fft.forward( right );
            }
            shadr.set(  "b",
                        fft.getAvg( binOffset + 0 ), fft.getAvg( binOffset + 1 ),
                        fft.getAvg( binOffset + 2 ), fft.getAvg( binOffset + 3 ) );
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
        float hEdge = getWidth() - ( 2. * fft.avgSize() + 3. ) * ( binWidth + gutter );
            // 2 channels + 1 left/right margin + 1 channel gutter
        
        float scale = 50.; // make the signal more visible

        // Background scrim: looks better without

        if ( left != null ) {
            fft.forward( left );
            for ( int i = 0; i < fft.avgSize(); ++i ) {
                fill( 1., .2, 0., i >= binOffset && i < binOffset + 4 ? 1. : .5 ); // alpha out bins not sent to the shader
                rect(   hEdge + ( i + 1. ) * ( binWidth + gutter ), getHeight() - 1.5 * srcFontSize - fft.getAvg( i ) * scale,
                        binWidth, fft.getAvg( i ) * scale );
            }
        }    
        if ( right != null ) {
            fft.forward( right );
            hEdge += ( fft.avgSize() + 1. ) * ( binWidth + gutter );
            for ( int i = 0; i < fft.avgSize(); ++i ) {
                fill( 1., .2, 0., i >= binOffset && i < binOffset + 4 ? 1. : .5 ); // alpha out bins not sent to the shader
                rect(   hEdge + ( i + 1. ) * ( binWidth + gutter ), getHeight() - 1.5 * srcFontSize - fft.getAvg( i ) * scale,
                        binWidth, fft.getAvg( i ) * scale );
            }
        }

        //
        // Display frame rate, upper right
        
        String fps = String.format( "%.2f fps", frameRate );
        
        textFont( srcFont );
        textSize( srcFontSize );
        textAlign( RIGHT, TOP );
        hEdge = getWidth() - 1.5 * srcFontSize;

        // Drop shadow
        translate( 1., 1. );
        fill( 0., .5 );
        text( fps, hEdge, 1.5 * srcFontSize );
        translate( -1., -1. );

        fill( 1., 1. ); // text color
        text( fps, hEdge, 1.5 * srcFontSize );

        popStyle();
    }
}
