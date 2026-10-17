-- Generated release-only gate. Missing/stale metadata is a hard refusal.
local o = Spring.GetModOptions() or {}
local function on(v) return v == true or v == 1 or v == '1' end
local function off(v) return v == false or v == 0 or v == '0' end
assert(o.prototype_diagnostic == nil or o.prototype_diagnostic == 'normal', 'release requires ordinary game mode')
for _, option in ipairs(VFS.Include('40k_configs/randomguy_options_schema.lua')) do
 if option.type == 'bool' and option.def == false then
  assert(not on(o[option.key]), 'release diagnostic option refused: '..option.key)
 end
end
if on(o.prototype_source_bounds_capture) then
 assert(off(o.prototype_demand_model_review), 'original release capture requires explicit demand=0')
 return false
end
VFS.Include('40k_configs/source_native_bounds_cache.lua').New()
return true
