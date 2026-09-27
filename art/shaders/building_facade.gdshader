shader_type spatial;
render_mode cull_disabled;
uniform vec2 bays = vec2(8.0, 12.0);
uniform vec4 masonry : source_color = vec4(0.42, 0.36, 0.31, 1.0);
uniform vec4 glass_color : source_color = vec4(0.09, 0.17, 0.21, 1.0);
uniform float variant = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float rectangle(vec2 p, vec2 lo, vec2 hi, vec2 aa) {
    vec2 a = smoothstep(lo-aa,lo+aa,p) * (1.0-smoothstep(hi-aa,hi+aa,p));
    return a.x*a.y;
}
void fragment() {
    vec2 grid = UV*bays;
    vec2 cell = floor(grid);
    vec2 p = fract(grid);
    vec2 aa = max(fwidth(grid),vec2(0.002));
    float seed = hash(cell+variant*13.0);
    float modern = step(3.5,variant);
    vec2 lo = mix(vec2(0.20,0.16),vec2(0.055,0.06),modern);
    vec2 hi = mix(vec2(0.80,0.81),vec2(0.945,0.91),modern);
    float recess = rectangle(p,lo-0.035,hi+0.04,aa);
    float window = rectangle(p,lo,hi,aa);
    float grain = hash(floor(UV*bays*90.0));
    vec3 wall = masonry.rgb * (0.93+0.09*grain);
    // Horizontal masonry joints and staggered brick courses, filtered at distance.
    vec2 brick = grid*vec2(4.0,9.0);
    brick.x += mod(floor(brick.y),2.0)*0.5;
    vec2 edge = min(fract(brick),1.0-fract(brick));
    vec2 brick_aa = max(fwidth(brick),vec2(0.01));
    float mortar = 1.0-smoothstep(0.015,0.04+brick_aa.x,edge.x)*smoothstep(0.015,0.04+brick_aa.y,edge.y);
    wall *= 1.0 - mortar*0.14*(1.0-modern)*clamp(1.0-length(brick_aa),0.0,1.0);
    float reflection = smoothstep(0.0,1.0,1.0-p.y)*0.26;
    vec3 glass = glass_color.rgb*(0.75+seed*0.45)+vec3(0.13,0.19,0.22)*reflection;
    float blinds = step(seed,0.37)*smoothstep(0.35,0.36,p.y);
    glass = mix(glass,masonry.rgb*0.48,blinds*0.7);
    float lit = step(0.89,seed);
    glass = mix(glass,vec3(0.55,0.36,0.16),lit*0.65);
    float mullion = (1.0-smoothstep(0.012,0.012+aa.x,abs(p.x-0.5)));
    glass = mix(glass,vec3(0.075,0.09,0.10),mullion*0.8);
    ALBEDO = mix(wall,masonry.rgb*0.32,recess);
    ALBEDO = mix(ALBEDO,glass,window);
    float sill = rectangle(p,vec2(lo.x-0.05,hi.y+0.025),vec2(hi.x+0.05,hi.y+0.065),aa);
    ALBEDO = mix(ALBEDO,masonry.rgb*1.25,sill);
    ROUGHNESS = mix(0.88,0.26,window);
    METALLIC = window*0.28;
    AO = mix(1.0,0.68,recess*(1.0-window));
    EMISSION = vec3(1.0,0.55,0.19)*lit*window*0.12;
}
