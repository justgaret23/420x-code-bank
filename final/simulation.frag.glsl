#version 300 es
precision mediump float;

in  vec4 agent_out;
out vec4 frag;

void main() {
  frag = agent_out;
} 
