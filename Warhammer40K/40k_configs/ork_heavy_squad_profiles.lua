-- Genuine existing Nob/Meganob actors. Native melee/egress acceptance pending.
-- Default-off recipe only; shared paid birth/repair/research machinery unchanged.
local M={Version=1}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local rows={
 {option='prototype_ork_nob_squad',key='ork_nob',id=12,product='ork_nob',member='ork_nob_member',capacity=3,spacing=26,
  name='Nob Mob',shortRole='Slugga and choppa mob',description='3 Nobz with sluggas and choppas per factory order. Builders heal survivors and restore casualties for resources.'},
 {option='prototype_ork_meganob_squad',key='ork_meganob',id=13,product='ork_meganob',member='ork_meganob_member',capacity=3,spacing=28,
  name='Meganob Mob',shortRole='Shoota and klaw mob',description='3 Meganobz with shootas and power klaws per factory order. Builders heal survivors and restore casualties for resources.'}}
function M.Profiles(base,options,sourceEnabled)
 options=options or{};local any=false;for _,r in ipairs(rows)do any=any or yes(options[r.option])end
 if not any then return base end
 assert(sourceEnabled==true,'Ork heavy squads require ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired Ork heavy squad scale085 candidate refused')
 local result=copy(base)
 for _,r in ipairs(rows)do if yes(options[r.option])then
  assert(not result.profiles[r.key]and not result.byID[r.id],'Ork heavy stable ID collision')
  for _,key in ipairs(result.order)do local p=result.profiles[key];assert(p.product~=r.product and p.member~=r.member,'Ork heavy actor collision')end
  local p=copy(r);p.option=nil;p.key=nil
  result.profiles[r.key]=p;result.byID[r.id]=r.key;result.order[#result.order+1]=r.key
 end end
 return result
end
return M
