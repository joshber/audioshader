// http://glslsandbox.com/e#24566.0

//return sin in range 0.0 to 1.0 instead of -1.0 to 1.0
float sin2(float a) {
	return pow(sin(a*.5),2.);
}
float karo(float angle) {
	return step(.5,sin2(angle));
}

void main() {
	vec2 p = surfacePosition*10.;
	vec3 c = vec3(0.);
	float a = atan(p.x,p.y);
	float r = length(p);
	float cc = sin2(a*10.+time)+sin2(r*10.+time);
	c.r = cc;
	c.g = cc*(2.-cc);
	c.b = 2.-cc;
	gl_FragColor = vec4(c,1);
}