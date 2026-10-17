-- Default-off homogeneous genuine Burna actors; shared paid squad owner only.
-- Capacity4 and body22M/110E/264work are the saved squad_content_recipes row.
-- Final ordinary definitions remain the sole pricing authority.
local M={Version=1,ProfileID=18}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function M.Profiles(base,options,sourceEnabled)
 options=options or{}
 if not yes(options.prototype_ork_burna_squad)then return base end
 assert(sourceEnabled==true,'Burna squad requires ordinary source progression')
 assert(not yes(options.prototype_scale085_pilot),'Unpaired Burna scale085 candidate refused')
 assert(not base.profiles.ork_burna and not base.byID[M.ProfileID],'Burna stable profile ID collision')
 for _,key in ipairs(base.order)do local p=base.profiles[key]
  assert(p.product~='ork_burna'and p.member~='ork_burna_member','Burna actor collision')
 end
 local result=copy(base)
 result.profiles.ork_burna={id=M.ProfileID,product='ork_burna',member='ork_burna_member',capacity=4,spacing=24,
  name='Burna Boyz Mob',shortRole='Flame mob',
  description='4 real Burna Boyz per paid factory order. Builders heal survivors and restore casualties for resources.'}
 result.byID[M.ProfileID]='ork_burna';result.order[#result.order+1]='ork_burna'
 return result
end
return M
