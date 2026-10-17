local M={Version=2}
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function M.Apply(defs,V,profiles)
 local result={products={}}
 local plans={};local used={}
 -- Preflight every family before touching definitions: no partial activation.
 for _,key in ipairs(profiles.order)do
  local p=assert(profiles.profiles[key]);assert(profiles.byID[p.id]==key,'Unstable profile ID')
  assert(p.capacity>=2 and p.capacity==math.floor(p.capacity),'Invalid squad capacity')
  local original=assert(defs[p.product],p.product);local cp=original.customparams or{}
  assert(type(original.buildpic)=='string'and original.buildpic~=''and V.FileExists('unitpics/'..original.buildpic),'Paid squad requires genuine product icon '..p.product)
  assert(not original.builder and original.canmove and(original.speed or 0)>0,'Squad product must be ordinary mobile infantry')
  assert(not cp.iscommander and cp.rosterrole~='commander'and cp.rosterrole~='builder','Commander/builder cannot become a squad')
  local special=p.sourceSpecial and assert(defs[p.sourceSpecial],p.sourceSpecial)
  assert((p.special and p.specialSlot and p.research and special)or(not p.special and not p.specialSlot and not p.research and not special),'Incomplete special role')
  for _,d in ipairs(special and{original,special}or{original})do
   local cp=d.customparams or{};assert(cp.animsource and d.objectname and d.script
    and V.FileExists('objects3d/'..d.objectname)and V.FileExists('scripts/'..d.script)
    and V.FileExists('scripts/generated/'..cp.animsource..'_anim.lua')
    and V.FileExists('unittextures/'..cp.animsource..'_tex1.png')and V.FileExists('unittextures/'..cp.animsource..'_tex2.png'),'Squad requires genuine complete actor')
  end
  for _,name in ipairs(p.special and{p.product,p.member,p.special}or{p.product,p.member})do assert(not used[name],'Duplicate squad definition '..name);used[name]=true end
  if cp.prototype40k_squad_product then
   assert(cp.prototype40k_squad_product==key and cp.prototype40k_squad_capacity==p.capacity,'Squad profile changed after pricing')
   assert(defs[p.member]and(not p.special or defs[p.special]),'Priced squad missing internal actors')
  else
   assert(not defs[p.member]and(not p.special or not defs[p.special]),'Internal actor key collision')
   for _,f in ipairs({'metalcost','energycost','buildtime'})do local n=original[f];assert(type(n)=='number'and n>0 and n<math.huge,'Invalid final body cost '..f)end
   plans[#plans+1]={key=key,p=p,original=original,special=special}
  end
  result.products[#result.products+1]=p.product
 end
 for _,plan in ipairs(plans)do
  local key,p,original,special=plan.key,plan.p,plan.original,plan.special
  -- Pinned native loader defaults mass to metal cost. Capture the ordinary
  -- body's mass before full-squad pricing changes that default on the leader.
  original.mass=math.max(1,math.min(1000000,tonumber(original.mass)or original.metalcost))
  defs[p.member]=copy(original);if special then defs[p.special]=copy(special)end
  for _,name in ipairs(p.special and{p.member,p.special}or{p.member})do
   local d=defs[name];local cp=d.customparams
   cp.prototype40k_squad_internal=1;cp.prototype40k_squad_profile=key
   cp.prototype40k_squad_profile_id=p.id
   cp.prototype40k_tech_requires=p.product;cp.prototype40k_donor=p.product
   cp.i18n_en_humanname=nil;cp.i18n_en_tooltip=nil
   d.description='Internal real squad member; produced only as paid squad membership'
   d.buildoptions={};d.builder=false -- Native loader iterates every final list.
  end
  local d=original;local cp=d.customparams
  cp.prototype40k_squad_product=key;cp.prototype40k_squad_capacity=p.capacity
  cp.prototype40k_squad_profile_id=p.id
  cp.prototype40k_squad_body_metal=d.metalcost;cp.prototype40k_squad_body_energy=d.energycost;cp.prototype40k_squad_body_work=d.buildtime
  cp.prototype40k_short_role=p.shortRole..' ('..p.capacity..' members)'
  d.name=p.name;d.description=p.description
  cp.prototype40k_ui_name=d.name;cp.prototype40k_ui_description=d.description;cp.prototype40k_ui_ready=1
  d.metalcost=d.metalcost*p.capacity;d.energycost=d.energycost*p.capacity;d.buildtime=d.buildtime*p.capacity
  cp.i18n_en_humanname=d.name;cp.i18n_en_tooltip=d.description
 end
 return result
end
function M.AddResearch(graph,profiles)
 for _,p in pairs(profiles.profiles)do if p.research then local row=copy(assert(p.researchRow,'Missing genuine research row'));assert(not graph.Research[p.research]);graph.Research[p.research]=row end end
 return graph
end
return M
