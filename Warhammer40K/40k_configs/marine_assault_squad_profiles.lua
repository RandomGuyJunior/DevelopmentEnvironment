-- Fixed paid Assault recipe. No jump implementation or readiness toggle here.
local M={Version=1,ProfileID=14,Command=34573}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function M.Profiles(base,options,sourceEnabled,jumpAdapter)
 options=options or{}
 if not yes(options.prototype_marine_assault_squad)then return base end
 assert(sourceEnabled==true,'Assault squad requires ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired Assault scale085 candidate refused')
 local p={id=M.ProfileID,product='imp_assault_marine',member='imp_assault_marine_member',capacity=4,spacing=28,
  name='Assault Marine Squad',shortRole='Bolt pistol and chainsword squad',
  description='One factory order buys all 4 Assault Marines with bolt pistols and chainswords; builders heal survivors and replace casualties for resources.'}
 -- A modoption/individual jump owner cannot certify whole-squad orders,
 -- per-body charge/clearance, flight identity, cancellation or persistence.
 assert(type(jumpAdapter)=='table'and jumpAdapter.Version==1 and jumpAdapter.Command==M.Command
  and type(jumpAdapter.SupportsFixedSquad)=='function'
  and jumpAdapter.SupportsFixedSquad(p.id,p.capacity,p.product,p.member)==true,
  'Assault whole-squad jump adapter unavailable; individual jump is insufficient')
 assert(not base.profiles.marine_assault and not base.byID[p.id],'Assault stable profile ID collision')
 for _,key in ipairs(base.order)do local r=base.profiles[key]
  assert(r.product~=p.product and r.member~=p.member,'Assault product/member collision')
 end
 local result=copy(base)
 result.profiles.marine_assault=p;result.byID[p.id]='marine_assault';result.order[#result.order+1]='marine_assault'
 return result
end
return M
