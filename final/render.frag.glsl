#version 300 es
#ifdef GL_ES
precision mediump float;
#endif

out vec4 color;
void main() {
  color = vec4( 0.,1.,1., .1 );
}

