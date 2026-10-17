-- Authored adapter; pinned BAR template is an ignored runtime dependency.
local basePath = "40k_reference/defaultmaterialtemplate.lua"
assert(VFS.FileExists(basePath), "40K tracks: missing ignored pinned base template " .. basePath)
local material = VFS.Include(basePath)
local fragmentGlobal = [[
#if RENDERING_MODE != 2
flat in vec3 prototypeTrackState;
vec2 PrototypeTrackUV(vec2 originalUV, vec3 state) {
    if (state.z < 0.5) return originalUV;
    // Source atlas rectangles, top-left pixel coordinates, 2048 square.
    vec2 pixel = vec2(originalUV.x, 1.0 - originalUV.y) * 2048.0;
    if (pixel.y < 8.0 || pixel.y > 904.0) return originalUV;
    float phase;
    if (pixel.x >= 8.0 && pixel.x <= 136.0) phase = state.x;
    else if (pixel.x >= 152.0 && pixel.x <= 280.0) phase = state.y;
    else return originalUV;
    // Seven identical 128-pixel repeats: wrap AFTER interpolation.
    float shiftedY = 8.0 + mod(pixel.y - 8.0 + phase * 128.0, 128.0);
    return vec2(originalUV.x, 1.0 - shiftedY / 2048.0);
}
#endif
]]
material.shaderPlugins = material.shaderPlugins or {}
local plugins = material.shaderPlugins
plugins.VERTEX_GLOBAL_NAMESPACE = (plugins.VERTEX_GLOBAL_NAMESPACE or "") .. [[
#if RENDERING_MODE != 2
flat out vec3 prototypeTrackState;
#endif
]]
plugins.VERTEX_UV_TRANSFORM = (plugins.VERTEX_UV_TRANSFORM or "") .. [[
prototypeTrackState = UNITUNIFORMS.userDefined[3].yzw;
]]
plugins.FRAGMENT_GLOBAL_NAMESPACE = (plugins.FRAGMENT_GLOBAL_NAMESPACE or "") .. fragmentGlobal
local seen = {}
for _, pass in ipairs({"shader", "deferred", "reflection", "shadow"}) do
    local shader = material[pass]
    if shader and not seen[shader] then
        seen[shader] = true
        assert(shader.vertex:find("%%VERTEX_UV_TRANSFORM%%", 1, true), "40K tracks: pinned vertex hook changed")
        assert(shader.fragment:find("%%FRAGMENT_GLOBAL_NAMESPACE%%", 1, true), "40K tracks: pinned fragment hook changed")
        local replaced, count = shader.fragment:gsub("vec2 myUV = uvCoords%.xy;", "vec2 myUV = PrototypeTrackUV(uvCoords.xy, prototypeTrackState);")
        assert(count == 1, "40K tracks: pinned fragment UV assignment changed")
        shader.fragment = replaced
    end
end
Spring.Echo("[40K tracks] pinned atlas shader adapter installed; uniforms13-15")
return material
