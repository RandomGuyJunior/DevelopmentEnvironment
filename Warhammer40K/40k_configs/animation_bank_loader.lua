-- Paired geometry selects a distinct immutable animation bank; clocks remain local.
local M={}
function M.Load(V,cache,cp)
 local source=assert(cp.animsource,'Source animation actor required')
 if cp.ork_v14_scale_bank then return V.Include('40k_configs/ork_v14_scale_reference.lua').LoadBank(V,cache,cp)end
 local bank=cp.scale_animation_bank
 local path='scripts/generated/'..source..'_anim.lua'
 if bank then
  local pilot=V.Include('40k_configs/scale_pilot.lua')
  local row=assert(pilot.Actors[source],'Unknown paired animation actor')
  assert(bank==row.bank and tonumber(cp.scale_pilot_factor)==pilot.Factor,'Mixed paired animation definition')
  path='scripts/40k_anim/'..bank..'.lua'
 else assert(not cp.scale_pilot_factor,'Scaled geometry without paired bank')end
 -- Existing source consumers share actor keys. Keep that baseline identity;
 -- paired banks need their own path key to avoid duplicate baseline tables.
 local cacheKey=bank and path or source
 local data=cache[cacheKey]
 if not data then data=assert(V.Include(path),'Missing animation bank');cache[cacheKey]=data end
 if bank then
  local meta=assert(data.scaleDerivative,'Missing paired animation provenance')
  assert(meta.factor==tonumber(cp.scale_pilot_factor)and meta.recipe=='translation-only-v1'
   and type(meta.baseSha256)=='string'and #meta.baseSha256==64 and meta.baseSha256:match('^[0-9a-f]+$'),'Invalid paired animation provenance')
  local pilot=V.Include('40k_configs/scale_pilot.lua');local row=pilot.Actors[source]
  if row.bankSourceSha256 then assert(meta.baseSha256==row.bankSourceSha256,'Wrong paired actor bank source')end
 else assert(not data.scaleDerivative,'Baseline path contains paired derivative')end
 return data
end
return M
