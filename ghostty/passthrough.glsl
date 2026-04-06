// Passthrough shader — enables background-image rendering in cmux.
// cmux's CAMetalLayer is opaque by default, which blocks background-image.
// Adding a custom shader forces libghostty to use an intermediate texture
// pipeline that preserves alpha, working around the opaque layer issue.
// See: https://github.com/manaflow-ai/cmux/issues/879
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    fragColor = texture(iChannel0, uv);
}
