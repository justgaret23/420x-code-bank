#version 300 es
in vec4 agent;

void main() {
  gl_PointSize = 20.;
  gl_Position = vec4( agent.x, agent.y, 0., 1. );
}
