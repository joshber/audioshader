# Audioshader

Josh Berson, joshwa.berson@gmail.com
2015 CC BY–NC–SA

## Purpose

This is an experiment in livecodeable audio-driven procedural video, inspired by the work of [h3xl3r](https://vimeo.com/h3xl3r).

## Notes

UI and dynamic range controls via the comment in the final line of the shader:

* “fft x y” means divide frequency spectrum into x log bins, which will be passed via vec4 a and b with an offset of y bins. So fft 8 4 passes the uppermost four octaves of an eight-octave spectrum. Default is 6 0

* “noshader” means hide the shader source.
* “nofreq” means hide the spectrum visualizer and framerate.
* “record x” starts a frame-by-frame recording in folder data/out/x. Shaders are saved on a per-frame basis too.

Shader validation needs refinement. At the moment, some noncompiling shaders still slip through, causing crashes.