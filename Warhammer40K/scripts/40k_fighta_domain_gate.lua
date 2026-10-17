-- Pure per-definition eligibility; this does not enable any old aircraft review.
local M={}
function M.Enabled(source,cp)
 cp=cp or{}
 return source=='ork_fighta_bomba'and cp.animsource=='ork_fighta_bomba'
  and cp.faction=='Orks'and tostring(cp.prototype40k_ork_aircraft_domain)=='1'
  and tostring(cp.prototype40k_genuine_air_domain)=='1'
  and tostring(cp.prototype40k_domain_asset_schema)=='1'
  and cp.source_entity=='attrib/ebps/races/orks/troops/ork_fighta_bomba.lua'
end
return M
