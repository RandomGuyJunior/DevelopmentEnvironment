-- Default-off I04 real-body candidates; native melee and phase gates pending.
-- Capacities reuse squad_content_recipes, authored BAR choices rather than DoW reinforcement.
local M={Version=1}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local rows={
 {option='prototype_necron_flayed_squad',key='necron_flayed',id=16,product='nec_flayed',member='nec_flayed_member',capacity=4,spacing=24,
  name='Flayed One Pack',shortRole='Flayer blade squad',description='One factory order buys all 4 Flayed Ones with native blades. Builders heal survivors and restore casualties for resources.'},
 {option='prototype_necron_wraith_squad',key='necron_wraith',id=17,product='nec_wraith',member='nec_wraith_member',capacity=3,spacing=28,
  name='Wraith Pack',shortRole='Phase claw squad',description='3 real Wraiths with native claws; builders heal survivors and restore casualties for resources.'}}
function M.Profiles(base,options,sourceEnabled)
 options=options or{};local any=false;for _,r in ipairs(rows)do any=any or yes(options[r.option])end
 if not any then return base end
 assert(sourceEnabled==true,'Necron melee squads require ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired Necron melee scale085 candidate refused')
 -- Review phase is currently single exact UnitDef; never claim it handles members.
 assert(not yes(options.prototype_necron_wraith_squad)or not yes(options.prototype_wraith_review),'Wraith squad phase adapter is not paired')
 local result=copy(base)
 for _,r in ipairs(rows)do if yes(options[r.option])then
  assert(not result.profiles[r.key]and not result.byID[r.id],'Necron melee stable profile ID collision')
  for _,key in ipairs(result.order)do local p=result.profiles[key];assert(p.product~=r.product and p.member~=r.member,'Necron melee product/member collision')end
  local p=copy(r);p.option=nil;p.key=nil
  result.profiles[r.key]=p;result.byID[r.id]=r.key;result.order[#result.order+1]=r.key
 end end
 return result
end
return M
