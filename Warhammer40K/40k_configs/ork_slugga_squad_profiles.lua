-- Default-off homogeneous genuine Slugga actors; shared paid squad owner only.
-- Capacity8 and body12M/60E/144work are the saved squad_content_recipes row.
-- Final ordinary definitions remain the sole pricing authority.
local M={Version=1,ProfileID=19}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function M.Profiles(base,options,sourceEnabled)
 options=options or{}
 if not yes(options.prototype_ork_slugga_squad)then return base end
 assert(sourceEnabled==true,'Slugga squad requires ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired Slugga scale085 candidate refused')
 assert(not base.profiles.ork_slugga and not base.byID[M.ProfileID],'Slugga stable profile ID collision')
 for _,key in ipairs(base.order)do local p=base.profiles[key]
  assert(p.product~='ork_slugga'and p.member~='ork_slugga_member','Slugga actor collision')
 end
 local result=copy(base)
 result.profiles.ork_slugga={id=M.ProfileID,product='ork_slugga',member='ork_slugga_member',capacity=8,spacing=24,
  name='Slugga Boyz Mob',shortRole='Slugga and choppa mob',
  description='8 real Slugga Boyz per paid factory order. Builders heal survivors and restore casualties for resources.'}
 result.byID[M.ProfileID]='ork_slugga';result.order[#result.order+1]='ork_slugga'
 return result
end
return M
