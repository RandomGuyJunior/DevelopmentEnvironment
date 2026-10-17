-- Default-off real-body Terminator pilot. Reuse final actor costs/weapons.
local M={Version=1}
local function yes(v)return v==true or v==1 or v=='1'end
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function M.Profiles(base,options,sourceEnabled)
 options=options or{}
 if not yes(options.prototype_marine_terminator_squad)then return base end
 assert(sourceEnabled==true,'Terminator squad requires ordinary source progression')
 if yes(options.prototype_scale085_pilot)then
  assert(yes(options.prototype_terminator_scale085_pair_pilot),'Unpaired Terminator scale085 candidate refused')
  VFS.Include('40k_configs/terminator_scale_pair.lua').ValidateClosure(options,VFS)
 end
 local p={id=15,product='imp_terminator',member='imp_terminator_member',capacity=3,spacing=28,
  name='Terminator Squad',shortRole='Storm bolter and power fist squad',
  description='One factory order buys all 3 Terminators with storm bolters and power fists; builders heal survivors and replace casualties for resources.'}
 assert(not base.profiles.marine_terminator and not base.byID[p.id],'Terminator stable profile ID collision')
 for _,key in ipairs(base.order)do local r=base.profiles[key]
  assert(r.product~=p.product and r.member~=p.member,'Terminator product/member collision')
 end
 local result=copy(base)
 result.profiles.marine_terminator=p;result.byID[p.id]='marine_terminator';result.order[#result.order+1]='marine_terminator'
 return result
end
return M
