import ddf.minim.*;

final int bufferSize = 1024; // TODO can we make this bigger to get a half-second of buffer? 22050?
final float sampleRate = 44100.;

Minim minim;
AudioInput input;
ShaderPipe pipe;

PShader shadr;

void setup() {
    size( 1280, 720, P2D );
    
    // Set up audio listener
    minim = new Minim( this );
    input = new minim.getLineIn( Minim.STEREO, bufferSize, sampleRate, 16/*bit depth: >16 not supported*/ );
    pipe = new ShaderPipe( shadr );
    input.addListener( pipe );
    
    refresh(); // load shader and configuration
    
    shadr.set( "resolution", float(width), float(height) );
}
    
void draw() {
    background( 0 );
    // blabla
    
    shadr.set( "time", float( millis() ) ); // float() bc GLSL < 3.0 can't do modulo on int
    pipe.passthru();

    shader( shadr );
    rect( 0, 0, width, height );
    
    //saveFrame( "data/out/######.jpg" ); // record frames
}

void refresh() {
    // load configuration, shader
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
}

class ShaderPipe implements AudioListener {
    private float[] left;
    private float[] right;
    
    private FFT fft;
    private int binSize; // frequency bands per bin passed to shader
    
    ShaderPipe() {
        right = left = null;
        fft = new FFT( bufferSize /2, sampleRate ); // /2 so we can offset sample frame to sample the past
        binSize = fft.specSize() /4; // 4 freq band binds, so spectrum fits in a vec4
    }
    
    synchroized void samples( float[] s ) {
        left = s;
    }
    synchronized void samples( float[] l, float[] r ) {
        left = l;
        right = r;
    }
    
    synchronized void passthru() {
        float[] l = new float[4];
        float[] r = new float[4];
        float acc;
        
        // for ( offset = 0 ... ) {
        // iterate forward( left, offset ) -- to get spectra for now plus a certain number into the past
        fft.forward( left );
        acc = 0.;
        for ( int i = 0; i < fft.specSize(); ++i ) {
            if ( 

        // FFT spectral decomposition -- vec4 for low, low-mid, hi-mid, hi
        // pass separate vec4s for now, -n ms ... -- to let us play with laminarities on different time scales
        // bin buffer values and set shader uniforms
        
        // maybe forget left/right and just take the spectrum of the mix?
        
        // ... buffer size / sample rate = time depth of buffer in seconds
        // http://code.compartmental.net/minim/javadoc/ddf/minim/analysis/FFT.html
    }
}