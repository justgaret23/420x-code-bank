#version 300 es
precision mediump float;

//last reported agent
in vec4 agent_in;

//texture containing position/velocity of all agents
uniform sampler2D flock;
//size of flock
uniform float agentCount;
uniform float time;
uniform float uniBoidDisplacement;
uniform vec2 gustDirection;
uniform vec2 congregateLocation;
uniform float congregationSpeed;
uniform float velocityLimit;
uniform bool invertRule;

//newly calculated position
out vec4 agent_out;

/*
Bind positions of vector
*/
vec4 bindPositions(vec4 agent){
  float flockXMin = -1.;
  float flockYMin = -1.;
  float flockXMax = 1.;
  float flockYMax = 1.;

  //TODO: inverse velocity depending on where it is
  //bound position rule
  if(agent.x < flockXMin) {
    agent.x *= -50.;
  } else if(agent.x > flockXMax){
    agent.x *= -50.;
  }

  if(agent.y < flockYMin){
    agent.y *= -50.;
  } else if(agent.y > flockYMax){
    agent.y *= -50.;
  }

  return agent;
}

vec4 limitVelocity(vec4 agent){

  //limit velocity - boid rule that helps keep everything consistent
  float vlim = .1;
  float mag = length( agent.zw );
  if( mag > vlim ) {
    agent.zw = (agent.zw / mag ) * vlim;
  }
  return agent;
}

vec4 syncVelocity(vec4 agent){
  //velocity sync
  vec2 agentVel = vec2(distance(agent_out.x, agent.x), distance(agent_out.y, agent.y));
  agent.zw += agentVel;

  //agent = limitVelocity(agent);

  return agent;
}

vec4 makeGust(vec4 agent, vec2 wind) {
  vec4 windGust = vec4(0.0, 0.0, 0.0, 0.0);
  windGust.xy = wind * 0.1;
  windGust.y = windGust.y * -1.0;
  return windGust;
}

/*
* The preferred location all agents have.
* it will move 1% of the way to the goal at each step
*/
vec2 preferredLocation(vec4 agent) {
  vec2 place = vec2(1.0, -1.0) * (congregateLocation / 10.);
  return (place - agent.xy) / congregationSpeed;
}

vec2 finalVelocityCalculations(vec2 perceivedVelocity, vec4 aOutVel){
  perceivedVelocity /= (agentCount - 1.0);
  vec2 newVelocity = perceivedVelocity.xy - aOutVel.zw;
  newVelocity /= 8.0;

  return newVelocity;
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
  float ruleMultiplier = 1.0;
  // loop through all agents...
  for( int i = 0; i < int( agentCount ); i++ ) { 
  
    // make sure the index isn't the index of our current agent
    //this is the boid comparer oops
    if( i == gl_VertexID ) continue;
    
    // get our agent for comparison. texelFetch accepts an integer
    // vector measured in pixels to determine the location of the
    // texture lookup. 
    vec4 agent  = texelFetch( flock, ivec2(i,0), 0 );
    agent = bindPositions(agent);

    //perceived center and velocity
    perceivedCenter += agent.xy;
    perceivedVelocity += syncVelocity(agent).zw;

    //keep away rule
    if(distance(agent.xy, agent_out.xy) < uniBoidDisplacement){
      boidDisplacement -= 12. * (agent.xy - agent_out.xy);
    }

    
    
  }

  //get velocity
  vec4 aOutVel = vec4((( agent_out.xy - perceivedCenter) * -.002 / agentCount), agent_in.zw);

  //run post-loop calculations for all three main boid rules
  perceivedCenter /= (agentCount - 1.0);
  boidDisplacement /= (agentCount - 1.0);
  perceivedVelocity = finalVelocityCalculations(perceivedVelocity, aOutVel);

  if(!invertRule){
    ruleMultiplier = abs(ruleMultiplier);
  } else {
    ruleMultiplier = ruleMultiplier * -1.0;
  }
  //Call all boid rules
  //aOutVel.xy += ruleMultiplier * (perceivedCenter.xy - agent_out.xy) * 0.001;
  aOutVel.xy += ruleMultiplier * boidDisplacement;
  aOutVel.xy += ruleMultiplier * preferredLocation(agent_out);
  aOutVel.zw += ruleMultiplier * perceivedVelocity;
  //aOutVel.xy += ruleMultiplier * makeGust(aOutVel, gustDirection).xy;

  //limit velocity before final calculations
  agent_out = limitVelocity(agent_out);

  //add final vel to agent_out
  agent_out += aOutVel;

  // each agent is one pixel. remember, this shader is not used for
  // rendering to the screen, only to our 1D texture array.
  gl_PointSize = 1.;
  gl_Position = vec4( idx, 0., 0., 1. );
}