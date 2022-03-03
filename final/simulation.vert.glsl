#version 300 es
precision mediump float;

//last reported agent
in vec4 agent_in;

//texture containing position/velocity of all agents
uniform sampler2D flock;
//size of flock
uniform float agentCount;
uniform float time;

//newly calculated position
out vec4 agent_out;


vec2 goToCenter(vec2 boid){
  vec2 perceivedCenter = vec2(0.0, 0.0);
  vec4 agent  = vec4(0.0, 0.0, 0.0, 0.0);

  //add agent/xy to perceived center
  perceivedCenter += agent.xy;

  //Divide perceivedCenter by total number of agents
  float totalAgents = agentCount - 1.0;
  perceivedCenter /= vec2(totalAgents, totalAgents);

  vec2 newCenter = perceivedCenter - agent.xy;
  perceivedCenter -= boid;
  perceivedCenter /= 100.0;

  return perceivedCenter;
}

bool checkPosition(vec2 agent, vec2 boid){
  if(distance(agent, boid) > 100.0){
       return true;
  } else {
    return false;
  }
}

/**
* boid rule that instructs the boids to stay away from each other
*/
vec2 keepAway(vec2 boid){
  vec2 c = vec2(0.0, 0.0);
  for(int i = 0; i < int( agentCount ); i++ ){
    // get the agent
    vec4 agent  = texelFetch( flock, ivec2(i,0), 0 );
    //compare the boid against every other boid except for itself
    if(boid != agent.xy){
      if(checkPosition(agent.xy, boid)){
        vec2 smallAgent = vec2(agent.x/1.0, agent.y/1.0);
        vec2 smallBoid = vec2(boid.x/1.0, boid.y/1.0);
        c = c - distance(agent.xy, boid);
        //c = c - (agent.xy - boid);
      }

    }
  }

  return c;
}

/*
* Boid rule that makes all boids velocity fall in line with each other
*/
vec2 syncVelocity(vec2 boid){
  vec2 perceivedVelocity = vec2(0.0, 0.0);
  float perceptionRadius = 100.0;

  //loop through all boids
  for(int i = 0; i < int( agentCount ); i++){
    vec4 agent  = texelFetch( flock, ivec2(i,0), 0 );
    if(boid != agent.xy && distance(agent.xy, boid) < perceptionRadius){
      vec2 agentVel = ( agent_out.xy - agent.xy) * -.002 / agentCount;
      perceivedVelocity += agentVel;
    }
  }
  //divide by agentCount
  float totalAgents = agentCount - 1.0;
  perceivedVelocity /= vec2(totalAgents, totalAgents);

  //subtract current boid velocity
  //TODO: ?????
  vec2 boidVel = (agent_out.xy - boid) * -.002 / agentCount;
  perceivedVelocity -= boidVel;

  float addedVel = 8.0;
  perceivedVelocity /= vec2(addedVel, addedVel);

  return perceivedVelocity;
}

void main() {
  // the position of this vertex needs to be reported
  // in the range {-1,1}. We can use the gl_VertexID
  // input variable to determine the current vertex's
  // position in the array and convert it to the desired range.
  float idx = -1. + (float( gl_VertexID ) / agentCount) * 2.; 

  // we'll use agent_out to send the agent position and velocity
  // to the fragment shader, which will render it to our 1D texture.
  // agent_out is also the target of our transform feedback.
  agent_out = agent_in;

  vec2 perceivedCenter = vec2(0.0, 0.0);
  vec2 boidDisplacement = vec2(0.0, 0.0);
  vec2 perceivedVelocity = vec2(0.0, 0.0);
  // loop through all agents...
  for( int i = 0; i < int( agentCount ); i++ ) { 
  
    // make sure the index isn't the index of our current agent
    //this is the boid comparer oops
    if( i == gl_VertexID ) continue;
    
    // get our agent for comparison. texelFetch accepts an integer
    // vector measured in pixels to determine the location of the
    // texture lookup. 
    vec4 agent  = texelFetch( flock, ivec2(i,0), 0 );
    

    //vec2 agentVel = ( agent_out.xy - agent.xy) * -.002 / agentCount;
    vec2 agentVel = vec2(distance(agent_out.x, agent.x), distance(agent_out.y, agent.y));
    perceivedCenter += agent.xy;
    if(distance(agent.xy, agent_out.xy) < 0.05){
      boidDisplacement -= (agent.xy - agent_out.xy);
    }
    perceivedVelocity += agentVel;
    //agentVel += goToCenter(agent.xy);
    //agentVel += keepAway(agent.xy);
    //agentVel += syncVelocity(agent.xy);

    // move our agent a small amount towards the ith agent
    // in the flock.
    //agent_out.xy += agentVel;
    //agent_out.xy += keepAway(agent.xy);
  }

  //get velocity
  vec2 aOutVel = agent_in.zw;
  aOutVel = ( agent_out.xy - perceivedCenter) * -.002 / agentCount;
  

  //perceivedCenter work
  perceivedCenter = perceivedCenter / vec2(agentCount - 1.0, agentCount - 1.0);
  //calculate perceivedCenter
  vec2 newCenter = perceivedCenter.xy - agent_out.xy;
  //perceivedCenter -= agent.xy;
  //newCenter /= 100.0;

  //alter boid displacement
  boidDisplacement /= agentCount;

  //perceived vel
  perceivedVelocity = perceivedVelocity / vec2(agentCount - 1.0, agentCount - 1.0);
  vec2 newVelocity = perceivedVelocity.xy - aOutVel;
  newVelocity /= 8.0;

  //Add everything to aOutVel
  aOutVel += (perceivedCenter.xy - agent_out.xy) * 0.001;
  //aOutVel += boidDisplacement;
  //aOutVel += newVelocity;

  //add final vel to agent_out
  agent_out.xy += aOutVel;
  agent_out.zw = aOutVel;
  //agent_out.xy += newCenter;

  //agent_out.xy += boidDisplacement;

  //agent_out.xy += perceivedVelocity;

  // each agent is one pixel. remember, this shader is not used for
  // rendering to the screen, only to our 1D texture array.
  gl_PointSize = 1.;
  gl_Position = vec4( idx, 0., 0., 1. );
}