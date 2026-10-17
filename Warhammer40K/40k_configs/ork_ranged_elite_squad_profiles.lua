-- Default-off genuine existing ranged Ork actors; shared controller/prices remain owned.
local M={Version=1}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local rows={
 {option='prototype_ork_tankbusta_squad',key='ork_tankbusta',id=10,product='ork_tankbusta',member='ork_tankbusta_member',capacity=3,spacing=24,
  name='Tankbusta Mob',shortRole='Rokkit mob',description='3 Tankbustas with rokkit launchas per factory order. Builders heal survivors and restore casualties for resources.'},
 {option='prototype_ork_loota_squad',key='ork_loota',id=11,product='ork_loota',member='ork_loota_member',capacity=3,spacing=26,
  name='Loota Mob',shortRole='Deffgun mob',description='3 Lootas with Deffguns per factory order. Builders heal survivors and restore casualties for resources.'}}
function M.Profiles(base,options,sourceEnabled)
 options=options or{};local any=false;for _,r in ipairs(rows)do any=any or yes(options[r.option])end
 if not any then return base end
 assert(sourceEnabled==true,'Ork ranged elites require ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired Ork ranged elite scale085 candidate refused')
 local result=copy(base)
 for _,r in ipairs(rows)do if yes(options[r.option])then
  assert(not result.profiles[r.key]and not result.byID[r.id],'Ork ranged elite stable ID collision')
  for _,key in ipairs(result.order)do local p=result.profiles[key];assert(p.product~=r.product and p.member~=r.member,'Ork ranged elite actor collision')end
  local p=copy(r);p.option=nil;p.key=nil
  result.profiles[r.key]=p;result.byID[r.id]=r.key;result.order[#result.order+1]=r.key
 end end
 return result
end
return M
