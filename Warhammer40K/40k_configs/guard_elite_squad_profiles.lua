-- Authored default-off full paid elite cohorts; no new actor or special weapons.
local M={Version=1}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local rows={
 {option='prototype_guard_kasrkin_squad',key='guard_kasrkin',id=5,product='imp_kasrkin',member='imp_kasrkin_member',capacity=5,spacing=20,
  name='Kasrkin Squad',shortRole='Hellgun squad',description='5 real Kasrkin with hellguns; builders heal survivors and restore casualties for resources.'},
 {option='prototype_guard_ogryn_squad',key='guard_ogryn',id=6,product='imp_ogryn',member='imp_ogryn_member',capacity=3,spacing=28,
  name='Ogryn Squad',shortRole='Ripper gun squad',description='3 real Ogryn with native ripper guns and fists; builders heal survivors and restore casualties for resources.'}}
function M.Profiles(base,options,sourceEnabled)
 options=options or{};local any=false;for _,r in ipairs(rows)do any=any or yes(options[r.option])end
 if not any then return base end
 assert(sourceEnabled==true,'Guard elite squads require ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired elite squad scale085 candidate refused')
 local result=copy(base)
 for _,r in ipairs(rows)do if yes(options[r.option])then
  assert(not result.profiles[r.key]and not result.byID[r.id],'Guard elite stable profile ID collision')
  for _,key in ipairs(result.order)do local p=result.profiles[key];assert(p.product~=r.product and p.member~=r.member,'Guard elite product/member collision')end
  local p=copy(r);p.option=nil;p.key=nil
  result.profiles[r.key]=p;result.byID[r.id]=r.key;result.order[#result.order+1]=r.key
 end end
 return result
end
return M
