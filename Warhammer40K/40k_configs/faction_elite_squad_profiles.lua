-- Default-off genuine ranged elite squads; source costs/weapons stay owned.
local M={Version=1}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local rows={
 {option='prototype_marine_scout_squad',key='marine_scout',id=7,product='imp_scout',member='imp_scout_member',capacity=4,spacing=22,
  name='Scout Marine Squad',shortRole='Scout bolter squad',description='One factory order buys all 4 Scout Marines; builders heal survivors and replace casualties for resources.'},
 {option='prototype_marine_heavy_squad',key='marine_heavy',id=8,product='imp_devastator',member='imp_devastator_member',capacity=3,spacing=24,
  name='Devastator Squad',shortRole='Heavy bolter squad',description='One factory order buys all 3 Devastators with heavy bolters; builders heal survivors and replace casualties for resources.'},
 {option='prototype_necron_immortal_squad',key='necron_immortal',id=9,product='nec_immortal',member='nec_immortal_member',capacity=3,spacing=26,
  name='Immortal Phalanx',shortRole='Gauss blaster phalanx',description='One factory order buys all 3 Immortals with native dual gauss emitters. Builders heal survivors and restore casualties for resources.'}}
function M.Profiles(base,options,sourceEnabled)
 options=options or{};local any=false;for _,r in ipairs(rows)do any=any or yes(options[r.option])end
 if not any then return base end
 assert(sourceEnabled==true,'Ranged elite squads require ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired ranged elite scale085 candidate refused')
 local result=copy(base)
 for _,r in ipairs(rows)do if yes(options[r.option])then
  assert(not result.profiles[r.key]and not result.byID[r.id],'Ranged elite stable profile ID collision')
  for _,key in ipairs(result.order)do local p=result.profiles[key];assert(p.product~=r.product and p.member~=r.member,'Ranged elite product/member collision')end
  local p=copy(r);p.option=nil;p.key=nil
  result.profiles[r.key]=p;result.byID[r.id]=r.key;result.order[#result.order+1]=r.key
 end end
 return result
end
return M
