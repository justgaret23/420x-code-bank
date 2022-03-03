import simulation_frag from './simulation.frag.glsl'
import simulation_vert from './simulation.vert.glsl'
import render_frag from './render.frag.glsl'
import render_vert from './render.vert.glsl'

// "global" variables
let gl,
  transformFeedback,
  framebuffer,
  simulationProgram, simulationPosition,
  renderProgram,
  buffers, uTime;

const textures = [],
      agentCount = 500

window.onload = function() {
  const canvas = document.getElementById( 'gl' )
  gl = canvas.getContext( 'webgl2' )
  canvas.width  = window.innerWidth
  canvas.height = window.innerHeight

  makeSimulationPhase()
  makeRenderPhase()
  makeTextures()

  framebuffer = gl.createFramebuffer()

  render()
}

let time = 0;
function render() {
  window.requestAnimationFrame( render )

  gl.useProgram(simulationProgram)
  
  time++
  gl.uniform1f( uTime, time )  

  gl.bindFramebuffer( gl.FRAMEBUFFER, framebuffer )
  
  // specify rendering to a width equal to the number of agents,
  // but only one high for simplicity of lookup
  gl.viewport( 0,0,agentCount, 1 )
  
  // render to textures[1], swap at end of render() 
  gl.framebufferTexture2D( gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, textures[1], 0 )
  
  // read from textures[0], swap at end of render()
  gl.activeTexture( gl.TEXTURE0 )
  gl.bindTexture(   gl.TEXTURE_2D, textures[0] )

  // feedback transform
  gl.bindBuffer( gl.ARRAY_BUFFER, buffers[0] )
  gl.vertexAttribPointer( simulationPosition, 4, gl.FLOAT, false, 0,0 )
  gl.bindBufferBase( gl.TRANSFORM_FEEDBACK_BUFFER, 0, buffers[1] )
  
  gl.beginTransformFeedback( gl.POINTS )  
  // draw via POINTS
  gl.drawArrays( gl.POINTS, 0, agentCount )
  gl.endTransformFeedback()

  gl.bindBufferBase( gl.TRANSFORM_FEEDBACK_BUFFER, 0, null )

  gl.bindFramebuffer( gl.FRAMEBUFFER, null )

  // important!!! last render was specified as only one pixel in height,
  // that won't do for rendering our quad
  gl.viewport( 0,0, gl.drawingBufferWidth, gl.drawingBufferHeight )

  gl.useProgram( renderProgram )
  gl.bindBuffer( gl.ARRAY_BUFFER, buffers[0] )
  gl.drawArrays( gl.POINTS, 0, agentCount )

  // swaps
  let tmp = buffers[0];  buffers[0] = buffers[1];  buffers[1] = tmp;
  tmp = textures[0]; textures[0] = textures[1]; textures[1] = tmp;
}

function makeSimulationPhase(){
  // pass in our vertex/fragment shader source code, and specify
  // that the attribute agent_out should be fed into transform feedback
  const shader = makeProgram( simulation_vert, simulation_frag, ['agent_out'])
  simulationProgram = shader[0]
  transformFeedback = shader[1]

  gl.useProgram( simulationProgram )

  buffers = makeSimulationBuffer()

  makeSimulationUniforms()
}

function makeSimulationBuffer() {
  const __agents = []
  for( let i = 0; i <= agentCount * 4; i+=4 ) {
    __agents[i] = -1 + Math.random() * 2
    __agents[i+1] = -1 + Math.random() * 2
    // use i+2 and i+3 to set initial velocities, default to 0
  }
  const agents = new Float32Array( __agents ) 

  // makeBuffers accepts initial data, number of buffers, and buffer usage
  // we'll make two buffers so we can complete the necessary swaps for
  // transform feedback
  return makeBuffers( agents, 2, gl.DYNAMIC_COPY )
}

function makeSimulationUniforms() {
  // this input variable will be fed by feedback
  const simulationPosition = gl.getAttribLocation( simulationProgram, 'agent_in' )
  gl.enableVertexAttribArray( simulationPosition )
  gl.vertexAttribPointer( simulationPosition, 4, gl.FLOAT, false, 0,0 )

  // number of agents in our flock
  const count  = gl.getUniformLocation( simulationProgram, 'agentCount' )
  gl.uniform1f(count, agentCount)
  uTime = gl.getUniformLocation( simulationProgram, 'time' )
}

/**
 * Outputs a shader program using a vertex shader, fragment shader, and optional transform feedback
 * @param {*} vert vertex shader
 * @param {*} frag fragment shader
 * @param {*} transform optional transform
 * @returns shader program
 */
function makeProgram( vert, frag, transform=null ) {
  let vertexShader = gl.createShader( gl.VERTEX_SHADER )
  gl.shaderSource( vertexShader, vert )
  gl.compileShader( vertexShader )
  let err = gl.getShaderInfoLog( vertexShader )
  if( err !== '' ) console.log( err )

  const fragmentShader = gl.createShader( gl.FRAGMENT_SHADER )
  gl.shaderSource( fragmentShader, frag )
  gl.compileShader( fragmentShader )
  err = gl.getShaderInfoLog( fragmentShader )
  if( err !== '' ) console.log( err )

  const program = gl.createProgram()
  gl.attachShader( program, vertexShader )
  gl.attachShader(program, fragmentShader)

  // transform feedback must happen before shader is linked / used.
  let trasformFeedback
  if( transform !== null ) {
    transformFeedback = gl.createTransformFeedback()
    gl.bindTransformFeedback(gl.TRANSFORM_FEEDBACK, transformFeedback)
    gl.transformFeedbackVaryings( program, transform, gl.SEPARATE_ATTRIBS )
  }
  
  gl.linkProgram( program )

  // return an array containing shader program and transform feedback
  // if feedback is enabled, otherwise just return shader program
  return transform === null ? program : [ program, transformFeedback ]
}

/**
 * Generates vertex buffer objects
 * @param {*} array 
 * @param {*} count 
 * @param {*} usage 
 * @returns 
 */
function makeBuffers( array, count=1, usage=gl.STATIC_DRAW ) {
  const buffer = gl.createBuffer()
  gl.bindBuffer( gl.ARRAY_BUFFER, buffer )
  gl.bufferData( gl.ARRAY_BUFFER, array, usage )

  let buffers = null
  if( count > 1) {
    buffers = [ buffer ]
    for( let i = 0; i < count; i++ ) {
      const buff = gl.createBuffer()
      gl.bindBuffer( gl.ARRAY_BUFFER, buff )
      gl.bufferData( gl.ARRAY_BUFFER, array.byteLength, usage )
      
      buffers.push( buff )
    }
  }

  return Array.isArray( buffers ) ? buffers : buffer
}

function makeRenderPhase() {
  renderProgram  = makeProgram( render_vert, render_frag )
  const renderPosition = gl.getAttribLocation( renderProgram, 'agent' )
  gl.enableVertexAttribArray( renderPosition )
  gl.vertexAttribPointer( renderPosition, 4, gl.FLOAT, false, 0,0 )

  gl.useProgram( renderProgram )
  //gl.enable(gl.BLEND)
  //gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA)
}

function makeTextures() {
  textures[0] = gl.createTexture()
  gl.bindTexture( gl.TEXTURE_2D, textures[0] )
  
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE )
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE )
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST )
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST )
  // width = agentCount, height = 1
  gl.texImage2D( gl.TEXTURE_2D, 0, gl.RGBA, agentCount, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, null )

  textures[1] = gl.createTexture()
  gl.bindTexture( gl.TEXTURE_2D, textures[1] )
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE )
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE )
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST )
  gl.texParameteri( gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST )
  gl.texImage2D( gl.TEXTURE_2D, 0, gl.RGBA, agentCount, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, null )
}