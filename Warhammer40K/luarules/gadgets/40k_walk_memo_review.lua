function gadget:GetInfo()return {name='40K exact walk memo counters',desc='Opted aggregate computation reuse evidence',author='Local project',layer=100000,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return end
local options=Spring.GetModOptions()
if tostring(options.prototype_walkmemo_stats or '0')~='1' or (options.prototype_diagnostic~='benchmark' and options.prototype_diagnostic~='combatbenchmark')then return end
local samples=0
function gadget:GameFrame(frame)
 if frame%300~=0 or samples>=20 then return end
 samples=samples+1
 local s=GG.Prototype40kWalkMemoStats
 if not s then Spring.Echo('40K WALK MEMO','UNAVAILABLE',frame);return end
 Spring.Echo('40K WALK MEMO','ACTUAL_COUNTERS',frame,s.hits,s.misses,s.stored,s.uncached,s.frameResets,s.capacity)
end
