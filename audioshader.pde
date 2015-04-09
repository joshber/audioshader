import ddf.minim.*;

Minim minim;
AudioInput input;
ShaderPipe pipe;

PShader shadr;

void setup() {
    size( 1280, 720, P2D );
    
    // Set up audio listener
    minim = new Minim( this );
    input = new minim.getLineIn( Minim.STEREO, 1024/*buffer len*/, 44100/*sample Hz*/, 16/*bit depth*/ );
    pipe = new ShaderPipe( shadr );
    input.addListener( pipe );
    
    // READ PARAMETERS FROM CONFIG, load shader etc
    
    shadr.set( "resolution", float(width), float(height) );
}
    
void draw() {
    background( color( 0., 0., 0., 1. ) ); // FIXME PARAMETERIZE?
    // blabla
    
    shadr.set( "time", float( millis() ) ); // float() bc GLSL < 3.0 can't do modulo on int
    pipe.passthru();

    shader( shadr );
    rect( 0, 0, width, height );
    
    //saveFrame( "data/out/######.jpg" ); // record frames
}
    
void stop() {
    input.close();
    minim.stop();
    
    super.stop();
}

void keyPressed() {
    if ( key == 'r' || key == 'R' ) {
        reloadConfig();
    }
}

class ShaderPipe implements AudioListener {
    private float[] left;
    private float[] right;
    private PShader shadr;
    
    ShaderPipe( PShader s ) {
        right = left = null;
        shadr = s;
    }
    
    synchroized void samples( float[] s ) {
        left = s;
    }
    synchronized void samples( float[] l, float[] r ) {
        left = l;
        right = r;
    }
    
    synchronized void passthru() {
        // bin buffer values and set shader uniforms
    }
}