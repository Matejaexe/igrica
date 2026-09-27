shader_type spatial;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_position.xz;
    float wear=noise(p*0.35);
    float aggregate=noise(p*35.0);
    float detail=clamp(1.0-length(fwidth(p))*8.0,0.0,1.0);
    ALBEDO=vec3(0.10,0.115,0.13)*(0.76+wear*0.35+aggregate*0.18*detail);
    ROUGHNESS=0.86+wear*0.10;
}
